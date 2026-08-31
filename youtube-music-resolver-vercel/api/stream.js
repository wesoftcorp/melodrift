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
    
    // Download audio stream directly through Innertube (inherits proxy automatically)
    const stream = await yt.download(videoId, {
      type: 'audio',
      quality: 'best',
      format: 'mp4',
    });

    res.setHeader('Content-Type', 'audio/mp4');
    res.setHeader('Accept-Ranges', 'bytes');
    
    const { Readable } = await import('stream');
    const nodeStream = Readable.fromWeb(stream);
    nodeStream.pipe(res);
  } catch (err) {
    if (!res.headersSent) res.status(500).json({ success: false, error: err.message });
  }
}
