import { Innertube, UniversalCache } from 'youtubei.js';

export default async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const { id: videoId } = req.query;

  if (!videoId) {
    return res.status(400).json({ success: false, error: 'Missing parameter "id"' });
  }

  try {
    const options = {
      cache: new UniversalCache(false)
    };

    if (process.env.YOUTUBE_COOKIE) {
      options.cookie = process.env.YOUTUBE_COOKIE;
    }

    if (process.env.YOUTUBE_PROXY) {
      const { ProxyAgent } = await import('undici');
      const { Platform } = await import('youtubei.js');
      const proxyAgent = new ProxyAgent(process.env.YOUTUBE_PROXY);
      options.fetch = async (input, init) => {
        return Platform.shim.fetch(input, {
          ...init,
          dispatcher: proxyAgent
        });
      };
    }

    const yt = await Innertube.create(options);
    const info = await yt.getInfo(videoId, 'MWEB');
    
    // Choose best audio stream
    const format = info.chooseFormat({ type: 'audio', quality: 'best' });
    
    if (!format) {
      return res.status(404).json({ success: false, error: 'No audio format found' });
    }
    
    // Decipher and return streaming URL if not already deciphered
    const streamUrl = format.url || format.decipher(yt.session.player);

    return res.status(200).json({
      success: true,
      url: streamUrl,
      bitrate: format.bitrate,
      mimeType: format.mime_type
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message });
  }
}
