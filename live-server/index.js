/**
 * 直播系统后端服务
 * 提供直播间管理、用户管理、弹幕服务等功能
 */

const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const PORT = 3000;
const DATA_DIR = path.join(__dirname, '..', 'data');
const CONFIG_DIR = path.join(__dirname, '..', 'config');
const VIDEO_DIR = path.join(__dirname, '..', 'videos');
const POPUP_DIR = path.join(__dirname, '..', 'popups');

// SRS流媒体服务器配置
const SRS_CONFIG = {
  host: process.env.SRS_HOST || 'localhost',
  rtmpPort: 1935,
  httpPort: 8080,
  httpsPort: 19350
};

// 确保目录存在
[DATA_DIR, CONFIG_DIR, VIDEO_DIR, POPUP_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// 配置视频上传
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, VIDEO_DIR);
  },
  filename: (req, file, cb) => {
    const uniqueName = Date.now() + '-' + crypto.randomUUID() + path.extname(file.originalname);
    cb(null, uniqueName);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 500 * 1024 * 1024 }, // 限制500MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.mp4', '.webm', '.flv', '.mkv', '.mov'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('不支持的视频格式'));
    }
  }
});

// 配置弹窗图片上传
const popupStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, POPUP_DIR);
  },
  filename: (req, file, cb) => {
    const uniqueName = Date.now() + '-' + crypto.randomUUID() + path.extname(file.originalname);
    cb(null, uniqueName);
  }
});

const uploadPopup = multer({
  storage: popupStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 限制10MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('不支持的图片格式'));
    }
  }
});

// 初始化数据存储
const db = {
  users: loadData('users.json', [
    { id: 1, username: 'admin', password: '123456', role: 'admin', nickname: '管理员', avatar: '' }
  ]),
  rooms: loadData('rooms.json', []),
  danmaku: loadData('danmaku.json', []),
  gifts: loadData('gifts.json', [
    { id: 1, name: '小心心', icon: 'heart', price: 1 },
    { id: 2, name: '棒棒糖', icon: 'lollipop', price: 10 },
    { id: 3, name: '蛋糕', icon: 'cake', price: 50 },
    { id: 4, name: '跑车', icon: 'car', price: 520 },
    { id: 5, name: '火箭', icon: 'rocket', price: 1314 }
  ]),
  popups: loadData('popups.json', [])
};

// 内存中存储直播间连接状态
const liveRooms = new Map(); // roomId -> { viewers: Set, streamKey: string, isLive: boolean }

/**
 * 从文件加载数据
 */
function loadData(filename, defaultData) {
  const filePath = path.join(DATA_DIR, filename);
  if (fs.existsSync(filePath)) {
    try {
      return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    } catch (e) {
      return defaultData;
    }
  }
  fs.writeFileSync(filePath, JSON.stringify(defaultData, null, 2));
  return defaultData;
}

/**
 * 保存数据到文件
 */
function saveData(filename, data) {
  const filePath = path.join(DATA_DIR, filename);
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

// 中间件
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));
app.use('/videos', express.static(VIDEO_DIR));
app.use('/popups', express.static(POPUP_DIR));

// 伪直播房间进程存储
const fakeLiveProcesses = new Map();

// ========== 用户相关接口 ==========

/**
 * 用户登录
 */
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const user = db.users.find(u => u.username === username && u.password === password);
  if (user) {
    res.json({
      success: true,
      data: {
        id: user.id,
        username: user.username,
        nickname: user.nickname,
        role: user.role,
        token: crypto.randomUUID()
      }
    });
  } else {
    res.json({ success: false, message: '用户名或密码错误' });
  }
});

/**
 * 获取用户列表
 */
app.get('/api/users', (req, res) => {
  res.json({ success: true, data: db.users });
});

/**
 * 创建用户
 */
app.post('/api/users', (req, res) => {
  const newUser = {
    id: db.users.length + 1,
    ...req.body,
    createdAt: new Date().toISOString()
  };
  db.users.push(newUser);
  saveData('users.json', db.users);
  res.json({ success: true, data: newUser });
});

// ========== 直播间相关接口 ==========

/**
 * 获取直播间列表
 */
app.get('/api/rooms', (req, res) => {
  const rooms = db.rooms.map(room => {
    const roomState = liveRooms.get(room.id);
    return {
      ...room,
      isLive: roomState?.isLive || false,
      viewerCount: roomState?.viewers?.size || 0
    };
  });
  res.json({ success: true, data: rooms });
});

/**
 * 获取单个直播间详情
 */
app.get('/api/rooms/:id', (req, res) => {
  const room = db.rooms.find(r => r.id === parseInt(req.params.id));
  if (room) {
    const roomState = liveRooms.get(room.id);
    res.json({
      success: true,
      data: {
        ...room,
        isLive: roomState?.isLive || false,
        viewerCount: roomState?.viewers?.size || 0
      }
    });
  } else {
    res.json({ success: false, message: '直播间不存在' });
  }
});

/**
 * 创建直播间
 */
app.post('/api/rooms', (req, res) => {
  const { title, cover, category, description, streamUrl, liveMode } = req.body;
  const newRoom = {
    id: db.rooms.length > 0 ? Math.max(...db.rooms.map(r => r.id)) + 1 : 1,
    title: title || '未命名直播间',
    cover: cover || '',
    category: category || '其他',
    description: description || '',
    streamUrl: streamUrl || '',
    streamKey: crypto.randomUUID(),
    liveMode: liveMode || 'normal', // normal: 正常直播, fake: 伪直播
    userId: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  db.rooms.push(newRoom);
  saveData('rooms.json', db.rooms);

  // 初始化直播间状态
  liveRooms.set(newRoom.id, {
    viewers: new Set(),
    streamKey: newRoom.streamKey,
    isLive: false
  });

  res.json({ success: true, data: newRoom });
});

/**
 * 更新直播间
 */
app.put('/api/rooms/:id', (req, res) => {
  const roomIndex = db.rooms.findIndex(r => r.id === parseInt(req.params.id));
  if (roomIndex !== -1) {
    db.rooms[roomIndex] = {
      ...db.rooms[roomIndex],
      ...req.body,
      updatedAt: new Date().toISOString()
    };
    saveData('rooms.json', db.rooms);
    res.json({ success: true, data: db.rooms[roomIndex] });
  } else {
    res.json({ success: false, message: '直播间不存在' });
  }
});

/**
 * 删除直播间
 */
app.delete('/api/rooms/:id', (req, res) => {
  const id = parseInt(req.params.id);
  db.rooms = db.rooms.filter(r => r.id !== id);
  saveData('rooms.json', db.rooms);
  liveRooms.delete(id);
  res.json({ success: true });
});

/**
 * 开始直播
 */
app.post('/api/rooms/:id/start', (req, res) => {
  const id = parseInt(req.params.id);
  const roomState = liveRooms.get(id);
  if (roomState) {
    roomState.isLive = true;
    res.json({ success: true, message: '直播已开始' });
  } else {
    // 创建直播间状态
    liveRooms.set(id, { viewers: new Set(), streamKey: '', isLive: true });
    res.json({ success: true, message: '直播已开始' });
  }
});

/**
 * 结束直播
 */
app.post('/api/rooms/:id/stop', (req, res) => {
  const id = parseInt(req.params.id);
  const roomState = liveRooms.get(id);
  if (roomState) {
    roomState.isLive = false;
    roomState.viewers.clear();
    
    // 通知所有观众直播结束
    broadcastToRoom(id, {
      type: 'system',
      data: {
        message: '直播已结束',
        viewerCount: 0
      }
    });
    
    res.json({ success: true, message: '直播已结束' });
  } else {
    res.json({ success: true, message: '直播已结束' });
  }
});

/**
 * 设置直播模式
 */
app.put('/api/rooms/:id/live-mode', (req, res) => {
  const id = parseInt(req.params.id);
  const { liveMode } = req.body;
  
  const roomIndex = db.rooms.findIndex(r => r.id === id);
  if (roomIndex === -1) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  if (!['normal', 'fake'].includes(liveMode)) {
    return res.json({ success: false, message: '无效的直播模式' });
  }
  
  db.rooms[roomIndex] = {
    ...db.rooms[roomIndex],
    liveMode: liveMode,
    updatedAt: new Date().toISOString()
  };
  saveData('rooms.json', db.rooms);
  res.json({ success: true, data: db.rooms[roomIndex] });
});

/**
 * 重新生成推流密钥
 */
app.post('/api/rooms/:id/regenerate-stream-key', (req, res) => {
  const id = parseInt(req.params.id);
  const roomIndex = db.rooms.findIndex(r => r.id === id);
  if (roomIndex === -1) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  const newStreamKey = crypto.randomUUID();
  db.rooms[roomIndex].streamKey = newStreamKey;
  db.rooms[roomIndex].updatedAt = new Date().toISOString();
  saveData('rooms.json', db.rooms);
  
  // 更新内存中的状态
  const roomState = liveRooms.get(id);
  if (roomState) {
    roomState.streamKey = newStreamKey;
  }
  
  res.json({ success: true, data: { streamKey: newStreamKey } });
});

/**
 * 获取SRS服务器配置
 */
app.get('/api/srs/config', (req, res) => {
  res.json({
    success: true,
    data: {
      host: SRS_CONFIG.host,
      rtmpPort: SRS_CONFIG.rtmpPort,
      httpPort: SRS_CONFIG.httpPort,
      httpsPort: SRS_CONFIG.httpsPort
    }
  });
});

/**
 * 获取直播推流地址
 */
app.get('/api/rooms/:id/stream-url', (req, res) => {
  const id = parseInt(req.params.id);
  const room = db.rooms.find(r => r.id === id);
  if (room) {
    const protocol = req.protocol;
    const host = req.get('host');
    const srsHost = SRS_CONFIG.host;
    
    // 根据直播模式返回不同的流地址
    if (room.liveMode === 'fake' || room.fakeLive) {
      // 伪直播模式
      if (room.videoFile) {
        const videoUrl = `${protocol}://${host}/videos/${room.videoFile}`;
        res.json({
          success: true,
          data: {
            rtmpUrl: `rtmp://${host}:1935/live/${room.id}?key=${room.streamKey}`,
            flvUrl: videoUrl,
            hlsUrl: videoUrl,
            streamKey: room.streamKey,
            liveMode: 'fake',
            videoUrl: videoUrl
          }
        });
      } else {
        res.json({
          success: true,
          data: {
            rtmpUrl: `rtmp://${host}:1935/live/${room.id}?key=${room.streamKey}`,
            flvUrl: '',
            hlsUrl: '',
            streamKey: room.streamKey,
            liveMode: 'fake',
            videoUrl: '',
            message: '请先上传视频文件并配置伪直播'
          }
        });
      }
    } else {
      // 正常直播模式
      const rtmpUrl = `rtmp://${srsHost}:${SRS_CONFIG.rtmpPort}/live/${room.id}?key=${room.streamKey}`;
      const flvUrl = `${protocol}://${host}/live/${room.id}.flv`;
      const hlsUrl = `${protocol}://${host}/live/${room.id}.m3u8`;
      
      res.json({
        success: true,
        data: {
          rtmpUrl: rtmpUrl,
          flvUrl: flvUrl,
          hlsUrl: hlsUrl,
          streamKey: room.streamKey,
          liveMode: 'normal',
          srsHost: srsHost,
          rtmpPort: SRS_CONFIG.rtmpPort
        }
      });
    }
  } else {
    res.json({ success: false, message: '直播间不存在' });
  }
});

// ========== 伪直播相关接口 ==========

/**
 * 上传视频文件
 */
app.post('/api/upload/video', upload.single('video'), (req, res) => {
  if (!req.file) {
    return res.json({ success: false, message: '请上传视频文件' });
  }
  
  res.json({
    success: true,
    data: {
      filename: req.file.filename,
      originalName: req.file.originalname,
      size: req.file.size,
      url: `/videos/${req.file.filename}`
    }
  });
});

/**
 * 获取可用视频列表
 */
app.get('/api/videos', (req, res) => {
  try {
    if (!fs.existsSync(VIDEO_DIR)) {
      return res.json({ success: true, data: [] });
    }
    
    const files = fs.readdirSync(VIDEO_DIR)
      .filter(file => {
        const ext = path.extname(file).toLowerCase();
        return ['.mp4', '.webm', '.flv', '.mkv', '.mov'].includes(ext);
      })
      .map(file => {
        const filePath = path.join(VIDEO_DIR, file);
        const stats = fs.statSync(filePath);
        return {
          filename: file,
          size: stats.size,
          url: `/videos/${file}`
        };
      });
    
    res.json({ success: true, data: files });
  } catch (e) {
    res.json({ success: false, message: '获取视频列表失败' });
  }
});

/**
 * 配置伪直播
 */
app.post('/api/rooms/:id/fake-live/setup', (req, res) => {
  const id = parseInt(req.params.id);
  const { videoFile, loopCount, autoStart } = req.body;
  
  const roomIndex = db.rooms.findIndex(r => r.id === id);
  if (roomIndex === -1) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  // 验证视频文件是否存在
  if (videoFile) {
    const videoPath = path.join(VIDEO_DIR, videoFile);
    if (!fs.existsSync(videoPath)) {
      return res.json({ success: false, message: '视频文件不存在' });
    }
  }
  
  // 更新直播间配置
  db.rooms[roomIndex] = {
    ...db.rooms[roomIndex],
    fakeLive: true,
    videoFile: videoFile || '',
    loopCount: loopCount || -1,
    fakeLiveStarted: false,
    updatedAt: new Date().toISOString()
  };
  
  saveData('rooms.json', db.rooms);
  
  // 如果设置为自动开始
  if (autoStart) {
    const roomState = liveRooms.get(id);
    if (roomState) {
      roomState.isLive = true;
    } else {
      liveRooms.set(id, { viewers: new Set(), streamKey: db.rooms[roomIndex].streamKey, isLive: true });
    }
    db.rooms[roomIndex].fakeLiveStarted = true;
    saveData('rooms.json', db.rooms);
  }
  
  res.json({ success: true, data: db.rooms[roomIndex] });
});

/**
 * 开始伪直播
 */
app.post('/api/rooms/:id/fake-live/start', (req, res) => {
  const id = parseInt(req.params.id);
  const room = db.rooms.find(r => r.id === id);
  
  if (!room) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  if (!room.videoFile) {
    return res.json({ success: false, message: '请先配置视频文件' });
  }
  
  // 更新状态
  const roomState = liveRooms.get(id);
  if (roomState) {
    roomState.isLive = true;
  } else {
    liveRooms.set(id, { viewers: new Set(), streamKey: room.streamKey, isLive: true });
  }
  
  // 更新数据库
  const roomIndex = db.rooms.findIndex(r => r.id === id);
  db.rooms[roomIndex].fakeLiveStarted = true;
  db.rooms[roomIndex].updatedAt = new Date().toISOString();
  saveData('rooms.json', db.rooms);
  
  // 广播直播开始消息
  broadcastToRoom(id, {
    type: 'system',
    data: { message: '伪直播已开始', isLive: true }
  });
  
  res.json({ success: true, message: '伪直播已开始' });
});

/**
 * 停止伪直播
 */
app.post('/api/rooms/:id/fake-live/stop', (req, res) => {
  const id = parseInt(req.params.id);
  const room = db.rooms.find(r => r.id === id);
  
  if (!room) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  // 更新状态
  const roomState = liveRooms.get(id);
  if (roomState) {
    roomState.isLive = false;
    roomState.viewers.clear();
  }
  
  // 更新数据库
  const roomIndex = db.rooms.findIndex(r => r.id === id);
  db.rooms[roomIndex].fakeLiveStarted = false;
  db.rooms[roomIndex].updatedAt = new Date().toISOString();
  saveData('rooms.json', db.rooms);
  
  // 广播直播结束消息
  broadcastToRoom(id, {
    type: 'system',
    data: { message: '伪直播已结束', isLive: false }
  });
  
  res.json({ success: true, message: '伪直播已结束' });
});

/**
 * 删除视频文件
 */
app.delete('/api/videos/:filename', (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(VIDEO_DIR, filename);
  
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      res.json({ success: true, message: '视频已删除' });
    } else {
      res.json({ success: false, message: '视频文件不存在' });
    }
  } catch (e) {
    res.json({ success: false, message: '删除失败' });
  }
});

/**
 * 获取伪直播FFmpeg命令
 */
app.get('/api/rooms/:id/ffmpeg-command', (req, res) => {
  const id = parseInt(req.params.id);
  const room = db.rooms.find(r => r.id === id);
  
  if (!room || !room.videoFile) {
    return res.json({ success: false, message: '请先配置伪直播' });
  }
  
  const protocol = req.protocol;
  const host = req.get('host');
  const videoUrl = `${protocol}://${host}/videos/${room.videoFile}`;
  const rtmpUrl = `rtmp://${host}:1935/live/${room.id}?key=${room.streamKey}`;
  
  const commands = {
    // 直接播放模式（不需要SRS）
    directPlay: {
      method: 'GET',
      url: videoUrl,
      description: '直接访问视频文件URL，适合简单伪直播'
    },
    // FFmpeg推流到SRS模式
    ffmpeg: {
      command: `ffmpeg -re -stream_loop ${room.loopCount || -1} -i "${videoUrl}" -c copy -tune zerolatency -f flv "${rtmpUrl}"`,
      description: '使用FFmpeg循环推流到SRS，低延迟播放'
    }
  };
  
  res.json({ success: true, data: commands });
});

// ========== 弹幕相关接口 ==========

/**
 * 获取弹幕列表
 */
app.get('/api/rooms/:id/danmaku', (req, res) => {
  const roomId = parseInt(req.params.id);
  const danmaku = db.danmaku.filter(d => d.roomId === roomId).slice(-100);
  res.json({ success: true, data: danmaku });
});

/**
 * 发送弹幕（HTTP接口）
 */
app.post('/api/rooms/:id/danmaku', (req, res) => {
  const roomId = parseInt(req.params.id);
  const { content, userId, nickname } = req.body;

  const danmaku = {
    id: Date.now(),
    roomId,
    content,
    userId: userId || 'anonymous',
    nickname: nickname || '匿名用户',
    color: req.body.color || '#FFFFFF',
    timestamp: Date.now()
  };

  db.danmaku.push(danmaku);
  if (db.danmaku.length > 1000) {
    db.danmaku = db.danmaku.slice(-500);
    saveData('danmaku.json', db.danmaku);
  }

  // 通过WebSocket广播弹幕
  broadcastToRoom(roomId, {
    type: 'danmaku',
    data: danmaku
  });

  res.json({ success: true, data: danmaku });
});

// ========== 礼物相关接口 ==========

/**
 * 获取礼物列表
 */
app.get('/api/gifts', (req, res) => {
  res.json({ success: true, data: db.gifts });
});

/**
 * 发送礼物
 */
app.post('/api/rooms/:id/gift', (req, res) => {
  const roomId = parseInt(req.params.id);
  const { giftId, userId, nickname, count } = req.body;
  const gift = db.gifts.find(g => g.id === giftId);

  if (gift) {
    const giftData = {
      id: Date.now(),
      roomId,
      giftId,
      giftName: gift.name,
      giftIcon: gift.icon,
      giftPrice: gift.price,
      count: count || 1,
      userId: userId || 'anonymous',
      nickname: nickname || '匿名用户',
      timestamp: Date.now()
    };

    // 通过WebSocket广播礼物
    broadcastToRoom(roomId, {
      type: 'gift',
      data: giftData
    });

    res.json({ success: true, data: giftData });
  } else {
    res.json({ success: false, message: '礼物不存在' });
  }
});

// ========== WebSocket 服务 ==========

/**
 * 广播消息到指定直播间
 */
function broadcastToRoom(roomId, message) {
  const roomState = liveRooms.get(roomId);
  if (roomState) {
    const data = JSON.stringify(message);
    roomState.viewers.forEach(ws => {
      if (ws.readyState === ws.OPEN) {
        ws.send(data);
      }
    });
  }
}

/**
 * WebSocket连接处理
 */
wss.on('connection', (ws, req) => {
  const urlParams = new URLSearchParams(req.url.split('?')[1] || '');
  const roomId = parseInt(urlParams.get('roomId'));

  if (roomId) {
    // 添加观众到直播间
    let roomState = liveRooms.get(roomId);
    if (!roomState) {
      roomState = { viewers: new Set(), streamKey: '', isLive: false };
      liveRooms.set(roomId, roomState);
    }
    roomState.viewers.add(ws);

    // 发送连接成功消息
    ws.send(JSON.stringify({
      type: 'connected',
      data: { roomId, viewerCount: roomState.viewers.size }
    }));

    // 广播新观众进入
    broadcastToRoom(roomId, {
      type: 'system',
      data: { message: '有新观众进入直播间', viewerCount: roomState.viewers.size }
    });
  }

  // 消息处理
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      const targetRoomId = parseInt(data.roomId);

      switch (data.type) {
        case 'danmaku':
          // 处理弹幕
          broadcastToRoom(targetRoomId, {
            type: 'danmaku',
            data: {
              id: Date.now(),
              roomId: targetRoomId,
              content: data.content,
              nickname: data.nickname || '匿名用户',
              color: data.color || '#FFFFFF',
              timestamp: Date.now()
            }
          });
          break;

        case 'gift':
          // 处理礼物
          broadcastToRoom(targetRoomId, {
            type: 'gift',
            data: data.data
          });
          break;

        case 'chat':
          // 处理聊天消息
          broadcastToRoom(targetRoomId, {
            type: 'chat',
            data: {
              id: Date.now(),
              roomId: targetRoomId,
              content: data.content,
              nickname: data.nickname || '匿名用户',
              timestamp: Date.now()
            }
          });
          break;
      }
    } catch (e) {
      console.error('WebSocket消息处理错误:', e);
    }
  });

  // 断开连接处理
  ws.on('close', () => {
    liveRooms.forEach((roomState, roomId) => {
      if (roomState.viewers.has(ws)) {
        roomState.viewers.delete(ws);
        broadcastToRoom(roomId, {
          type: 'system',
          data: { message: '有观众离开直播间', viewerCount: roomState.viewers.size }
        });
      }
    });
  });
});

// ========== SRS 流媒体配置 ==========

/**
 * 获取SRS配置信息
 */
app.get('/api/srs/config', (req, res) => {
  const protocol = req.protocol;
  const host = req.get('host');
  res.json({
    success: true,
    data: {
      rtmp: {
        port: 1935,
        url: `rtmp://${host}:1935/live`
      },
      httpFlv: {
        port: 8080,
        url: `${protocol}://${host}:8080/live`
      },
      hls: {
        port: 8080,
        url: `${protocol}://${host}:8080/live`
      }
    }
  });
});

// ========== 健康检查接口 ==========

/**
 * 健康检查接口（用于 Docker 健康检查）
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: Date.now()
  });
});

// ========== 统计接口 ==========

/**
 * 获取统计数据
 */
app.get('/api/stats', (req, res) => {
  const stats = {
    totalRooms: db.rooms.length,
    liveRooms: Array.from(liveRooms.values()).filter(r => r.isLive).length,
    totalViewers: Array.from(liveRooms.values()).reduce((sum, r) => sum + r.viewers.size, 0),
    totalDanmaku: db.danmaku.length
  };
  res.json({ success: true, data: stats });
});

// ========== 弹窗图片相关接口 ==========

/**
 * 上传弹窗图片
 */
app.post('/api/popups/upload', uploadPopup.single('image'), (req, res) => {
  if (!req.file) {
    return res.json({ success: false, message: '请上传图片文件' });
  }
  
  const protocol = req.protocol;
  const host = req.get('host');
  const imageUrl = `${protocol}://${host}/popups/${req.file.filename}`;
  
  const newPopup = {
    id: db.popups.length > 0 ? Math.max(...db.popups.map(p => p.id)) + 1 : 1,
    name: req.body.name || req.file.originalname,
    filename: req.file.filename,
    url: imageUrl,
    size: req.file.size,
    mimeType: req.file.mimetype,
    width: req.body.width || 0,
    height: req.body.height || 0,
    createdAt: new Date().toISOString()
  };
  
  db.popups.push(newPopup);
  saveData('popups.json', db.popups);
  res.json({ success: true, data: newPopup });
});

/**
 * 获取弹窗图片列表
 */
app.get('/api/popups', (req, res) => {
  res.json({ success: true, data: db.popups });
});

/**
 * 删除弹窗图片
 */
app.delete('/api/popups/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const popupIndex = db.popups.findIndex(p => p.id === id);
  
  if (popupIndex === -1) {
    return res.json({ success: false, message: '弹窗图片不存在' });
  }
  
  // 删除文件
  const popup = db.popups[popupIndex];
  const filePath = path.join(POPUP_DIR, popup.filename);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }
  
  db.popups.splice(popupIndex, 1);
  saveData('popups.json', db.popups);
  res.json({ success: true });
});

/**
 * 配置直播间弹窗图片
 */
app.post('/api/rooms/:id/popup', (req, res) => {
  const roomId = parseInt(req.params.id);
  const { popupId, enabled, displayDuration, delayTime } = req.body;
  
  const roomIndex = db.rooms.findIndex(r => r.id === roomId);
  if (roomIndex === -1) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  // 如果指定了弹窗图片，检查是否存在
  if (popupId) {
    const popup = db.popups.find(p => p.id === popupId);
    if (!popup) {
      return res.json({ success: false, message: '弹窗图片不存在' });
    }
  }
  
  // 更新直播间的弹窗配置
  db.rooms[roomIndex] = {
    ...db.rooms[roomIndex],
    popupConfig: {
      popupId: popupId || null,
      enabled: enabled !== undefined ? enabled : true,
      displayDuration: displayDuration || 5,  // 显示时长（秒）
      delayTime: delayTime || 3  // 延迟显示时间（秒）
    },
    updatedAt: new Date().toISOString()
  };
  
  saveData('rooms.json', db.rooms);
  res.json({ success: true, data: db.rooms[roomIndex].popupConfig });
});

/**
 * 获取直播间弹窗配置
 */
app.get('/api/rooms/:id/popup', (req, res) => {
  const roomId = parseInt(req.params.id);
  const room = db.rooms.find(r => r.id === roomId);
  
  if (!room) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  const popupConfig = room.popupConfig || {
    popupId: null,
    enabled: false,
    displayDuration: 5,
    delayTime: 3
  };
  
  // 如果配置了弹窗图片，返回图片信息
  if (popupConfig.popupId) {
    const popup = db.popups.find(p => p.id === popupConfig.popupId);
    if (popup) {
      popupConfig.image = popup;
    }
  }
  
  res.json({ success: true, data: popupConfig });
});

/**
 * 立即弹出弹窗（实时推送）
 */
app.post('/api/rooms/:id/popup/trigger', (req, res) => {
  const roomId = parseInt(req.params.id);
  const { popupId, displayDuration } = req.body;
  
  const roomIndex = db.rooms.findIndex(r => r.id === roomId);
  if (roomIndex === -1) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  // 获取弹窗图片信息
  let popupImage = null;
  if (popupId) {
    popupImage = db.popups.find(p => p.id === popupId);
  } else {
    // 如果没有指定弹窗图片，使用直播间配置的弹窗
    const room = db.rooms[roomIndex];
    if (room.popupConfig?.popupId) {
      popupImage = db.popups.find(p => p.id === room.popupConfig.popupId);
    }
  }
  
  if (!popupImage) {
    return res.json({ success: false, message: '请选择弹窗图片' });
  }
  
  // 推送弹窗消息到直播间所有观众
  broadcastToRoom(roomId, {
    type: 'popup',
    data: {
      id: Date.now(),
      roomId: roomId,
      image: popupImage,
      displayDuration: displayDuration || 5,
      timestamp: Date.now()
    }
  });
  
  res.json({ 
    success: true, 
    message: '弹窗已推送',
    data: { image: popupImage, displayDuration: displayDuration || 5 }
  });
});

/**
 * 定时弹出弹窗
 */
app.post('/api/rooms/:id/popup/schedule', (req, res) => {
  const roomId = parseInt(req.params.id);
  const { popupId, displayDuration, scheduleTime, delaySeconds } = req.body;
  
  const roomIndex = db.rooms.findIndex(r => r.id === roomId);
  if (roomIndex === -1) {
    return res.json({ success: false, message: '直播间不存在' });
  }
  
  // 获取弹窗图片信息
  let popupImage = null;
  if (popupId) {
    popupImage = db.popups.find(p => p.id === popupId);
  } else {
    const room = db.rooms[roomIndex];
    if (room.popupConfig?.popupId) {
      popupImage = db.popups.find(p => p.id === room.popupConfig.popupId);
    }
  }
  
  if (!popupImage) {
    return res.json({ success: false, message: '请选择弹窗图片' });
  }
  
  let delayMs = 0;
  
  if (scheduleTime) {
    // 指定时间点弹出
    const targetTime = new Date(scheduleTime).getTime();
    const now = Date.now();
    delayMs = targetTime - now;
    
    if (delayMs <= 0) {
      return res.json({ success: false, message: '指定时间已过' });
    }
  } else if (delaySeconds) {
    // 延迟秒数弹出
    delayMs = parseInt(delaySeconds) * 1000;
  } else {
    return res.json({ success: false, message: '请指定弹出时间或延迟秒数' });
  }
  
  // 存储定时任务信息
  const scheduledTask = {
    id: Date.now(),
    roomId: roomId,
    popupImage: popupImage,
    displayDuration: displayDuration || 5,
    scheduleTime: scheduleTime || new Date(Date.now() + delayMs).toISOString(),
    delayMs: delayMs,
    createdAt: new Date().toISOString()
  };
  
  // 保存定时任务（用于查询和管理）
  if (!db.scheduledPopups) {
    db.scheduledPopups = [];
  }
  db.scheduledPopups.push(scheduledTask);
  saveData('scheduled_popups.json', db.scheduledPopups);
  
  // 设置定时器
  setTimeout(() => {
    // 推送弹窗
    broadcastToRoom(roomId, {
      type: 'popup',
      data: {
        id: Date.now(),
        roomId: roomId,
        image: popupImage,
        displayDuration: displayDuration || 5,
        timestamp: Date.now()
      }
    });
    
    // 移除已执行的定时任务
    db.scheduledPopups = db.scheduledPopups.filter(t => t.id !== scheduledTask.id);
    saveData('scheduled_popups.json', db.scheduledPopups);
    
    console.log(`[定时弹窗] 直播间 ${roomId} 弹窗已执行: ${popupImage.name}`);
  }, delayMs);
  
  res.json({ 
    success: true, 
    message: `弹窗将在 ${Math.round(delayMs / 1000)} 秒后弹出`,
    data: {
      taskId: scheduledTask.id,
      scheduleTime: scheduledTask.scheduleTime,
      delaySeconds: Math.round(delayMs / 1000)
    }
  });
});

/**
 * 获取定时弹窗任务列表
 */
app.get('/api/scheduled-popups', (req, res) => {
  const tasks = db.scheduledPopups || [];
  res.json({ success: true, data: tasks });
});

/**
 * 取消定时弹窗任务
 */
app.delete('/api/scheduled-popups/:id', (req, res) => {
  const id = parseInt(req.params.id);
  if (!db.scheduledPopups) {
    return res.json({ success: false, message: '没有定时任务' });
  }
  
  const taskIndex = db.scheduledPopups.findIndex(t => t.id === id);
  if (taskIndex === -1) {
    return res.json({ success: false, message: '任务不存在' });
  }
  
  db.scheduledPopups.splice(taskIndex, 1);
  saveData('scheduled_popups.json', db.scheduledPopups);
  res.json({ success: true, message: '任务已取消' });
});

// ========== 启动服务 ==========

server.listen(PORT, () => {
  console.log(`
============================================
  直播系统后端服务已启动
============================================
  HTTP 服务: http://localhost:${PORT}
  API 文档: http://localhost:${PORT}/api/rooms
  WebSocket: ws://localhost:${PORT}
============================================
  账号: admin / 123456
============================================
  配套服务:
  - SRS 流媒体: rtmp://localhost:1935/live
  - FFmpeg 推流: ffmpeg -re -stream_loop -1 -i video.mp4 -c copy -f flv rtmp://localhost:1935/live/房间ID
============================================
  按 Ctrl+C 停止服务
============================================
  `);
});
