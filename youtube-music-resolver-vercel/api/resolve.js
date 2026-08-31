import { Innertube, UniversalCache } from 'youtubei.js';

export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
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
      cache: new UniversalCache(false),
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
          dispatcher: proxyAgent,
        });
      };
    }

    const yt = await Innertube.create(options);

    // Try multiple clients for bot-detection resilience
    // MWEB → IOS → TV_EMBEDDED fallback chain
    let info = null;
    const clients = ['MWEB', 'IOS', 'TV_EMBEDDED'];
    let lastError = null;

    for (const client of clients) {
      try {
        info = await yt.getInfo(videoId, client);
        if (info?.streaming_data?.adaptive_formats?.length > 0) break;
      } catch (err) {
        lastError = err;
      }
    }

    if (!info) {
      throw lastError || new Error('Could not fetch video info from any client');
    }

    // Prioritize mp4/aac audio for Windows Media Foundation compatibility
    const formats = info.streaming_data?.adaptive_formats || [];
    let format = formats
      .filter(f => f.mime_type && f.mime_type.includes('audio/mp4'))
      .sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0))[0];

    if (!format) {
      // Fallback to best available audio format
      format = info.chooseFormat({ type: 'audio', quality: 'best' });
    }

    if (!format) {
      return res.status(404).json({ success: false, error: 'No audio format found' });
    }

    // Decipher the streaming URL
    const streamUrl = format.url || format.decipher(yt.session.player);

    if (!streamUrl) {
      return res.status(500).json({ success: false, error: 'Could not decipher stream URL' });
    }

    return res.status(200).json({
      success: true,
      url: streamUrl,
      bitrate: format.bitrate,
      mimeType: format.mime_type,
    });

  } catch (e) {
    return res.status(500).json({ success: false, error: e.message });
  }
}
