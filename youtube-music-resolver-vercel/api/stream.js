import { Innertube, UniversalCache, Platform } from 'youtubei.js';

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

    const streamUrl = format.url || format.decipher(yt.session.player);
    if (!streamUrl) return res.status(500).json({ success: false, error: 'Could not decipher stream URL' });

    // Fetch the raw media URL through the Webshare proxy dispatcher
    const upstream = await Platform.shim.fetch(streamUrl, {
      dispatcher: proxyDispatcher,
      headers: {
        ...(req.headers['range'] ? { 'Range': req.headers['range'] } : {}),
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': '*/*',
      }
    });

    res.status(upstream.status);
    const ct = upstream.headers.get('content-type');
    if (ct) res.setHeader('Content-Type', ct);
    const cl = upstream.headers.get('content-length');
    if (cl) res.setHeader('Content-Length', cl);
    const cr = upstream.headers.get('content-range');
    if (cr) res.setHeader('Content-Range', cr);
    res.setHeader('Accept-Ranges', 'bytes');

    const { Readable } = await import('stream');
    const nodeStream = Readable.fromWeb(upstream.body);
    nodeStream.pipe(res);
  } catch (err) {
    if (!res.headersSent) res.status(500).json({ success: false, error: err.message });
  }
}
