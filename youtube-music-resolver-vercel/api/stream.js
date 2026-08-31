import { Innertube, UniversalCache } from 'youtubei.js';

export const config = {
  api: {
    responseLimit: false,
    bodyParser: false,
  },
};

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Range');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const { id: videoId } = req.query;

  if (!videoId) {
    return res.status(400).json({ success: false, error: 'Missing parameter "id"' });
  }

  try {
    const options = { cache: new UniversalCache(false) };

    if (process.env.YOUTUBE_COOKIE) {
      options.cookie = process.env.YOUTUBE_COOKIE;
    }

    if (process.env.YOUTUBE_PROXY) {
      const { ProxyAgent } = await import('undici');
      const { Platform } = await import('youtubei.js');
      const proxyAgent = new ProxyAgent(process.env.YOUTUBE_PROXY);
      options.fetch = async (input, init) =>
        Platform.shim.fetch(input, { ...init, dispatcher: proxyAgent });
    }

    const yt = await Innertube.create(options);
    const info = await yt.getInfo(videoId, 'MWEB');

    const formats = info.streaming_data?.adaptive_formats || [];
    let format = formats
      .filter(f => f.mime_type && f.mime_type.includes('audio/mp4'))
      .sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0))[0];

    if (!format) format = info.chooseFormat({ type: 'audio', quality: 'best' });
    if (!format) return res.status(404).json({ success: false, error: 'No audio format found' });

    const streamUrl = format.url || format.decipher(yt.session.player);
    if (!streamUrl) return res.status(500).json({ success: false, error: 'Could not decipher stream URL' });

    const rangeHeader = req.headers['range'];
    const upstream = await fetch(streamUrl, {
      headers: {
        ...(rangeHeader ? { 'Range': rangeHeader } : {}),
        'User-Agent': 'Mozilla/5.0 (compatible)',
        'Accept': '*/*',
      },
    });

    res.status(upstream.status);
    const ct = upstream.headers.get('content-type');
    if (ct) res.setHeader('Content-Type', ct);
    const cl = upstream.headers.get('content-length');
    if (cl) res.setHeader('Content-Length', cl);
    const cr = upstream.headers.get('content-range');
    if (cr) res.setHeader('Content-Range', cr);
    res.setHeader('Accept-Ranges', 'bytes');

    const reader = upstream.body.getReader();
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
