import { Innertube, UniversalCache } from 'youtubei.js';

export const config = {
  api: { responseLimit: false, bodyParser: false },
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
    if (process.env.YOUTUBE_PROXY) {
      const { ProxyAgent } = await import('undici');
      const { Platform } = await import('youtubei.js');
      const proxyAgent = new ProxyAgent(process.env.YOUTUBE_PROXY);
      options.fetch = async (input, init) =>
        Platform.shim.fetch(input, { ...init, dispatcher: proxyAgent });
    }

    const yt = await Innertube.create(options);
    const info = await yt.getInfo(videoId, 'MWEB');

    // Use youtubei.js's own download() pipeline — no raw googlevideo URL is
    // re-fetched externally, so no IP mismatch and no 403.
    const stream = await info.download({
      type: 'audio',
      quality: 'best',
      format: 'mp4',
    });

    res.setHeader('Content-Type', 'audio/mp4');
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Transfer-Encoding', 'chunked');
    res.status(200);

    const reader = stream.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const canContinue = res.write(Buffer.from(value));
      if (!canContinue) await new Promise(r => res.once('drain', r));
    }
    res.end();
  } catch (err) {
    if (!res.headersSent) res.status(500).json({ success: false, error: err.message });
  }
}
