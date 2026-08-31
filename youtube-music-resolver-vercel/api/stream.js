import { Innertube, UniversalCache } from 'youtubei.js';

export const config = {
  api: { responseLimit: false },
};

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Range');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const { id: videoId } = req.query;
  if (!videoId) return res.status(400).json({ success: false, error: 'Missing parameter "id"' });

  try {
    const options = { cache: new UniversalCache(false) };
    if (process.env.YOUTUBE_COOKIE) options.cookie = process.env.YOUTUBE_COOKIE;
    
    let proxyDispatcher = null;
    if (process.env.YOUTUBE_PROXY) {
      const { ProxyAgent } = await import('undici');
      const { Platform } = await import('youtubei.js');
      proxyDispatcher = new ProxyAgent(process.env.YOUTUBE_PROXY);
      options.fetch = async (input, init) =>
        Platform.shim.fetch(input, { ...init, dispatcher: proxyDispatcher });
    }

    const yt = await Innertube.create(options);
    
    let info = null;
    for (const client of ['MWEB', 'IOS', 'ANDROID', 'TV_EMBEDDED']) {
      try {
        info = await yt.getInfo(videoId, client);
        if (info?.streaming_data?.adaptive_formats?.length > 0) break;
      } catch (_) {}
    }
    if (!info) throw new Error('Could not fetch video info');

    const formats = info.streaming_data?.adaptive_formats || [];
    let format = formats
      .filter(f => f.mime_type && f.mime_type.includes('audio/mp4'))
      .sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0))[0];

    if (!format) format = info.chooseFormat({ type: 'audio', quality: 'best' });
    if (!format) return res.status(404).json({ success: false, error: 'No audio format found' });

    // Download stream using Innertube's format.download() which handles deciphering + proxy
    const webStream = await format.download(yt.session);

    res.setHeader('Content-Type', 'audio/mp4');
    res.setHeader('Accept-Ranges', 'bytes');

    const { Readable } = await import('stream');
    const nodeStream = Readable.fromWeb(webStream);
    nodeStream.pipe(res);
  } catch (err) {
    if (!res.headersSent) res.status(500).json({ success: false, error: err.message });
  }
}
