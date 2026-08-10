<template>
  <div class="room-player">
    <div class="player-container">
      <video 
        ref="videoRef" 
        class="video-player"
        autoplay 
        controls
        playsinline
      ></video>
      
      <div v-if="!isPlaying" class="player-overlay">
        <div class="overlay-content">
          <p class="no-stream-text">
            {{ isLive ? '正在连接直播...' : '主播未开播' }}
          </p>
          <p v-if="streamUrl" class="stream-url">
            推流地址: {{ streamUrl }}
          </p>
        </div>
      </div>

      <div class="player-header">
        <button class="back-btn" @click="$emit('back')">← 返回</button>
        <h2 class="room-title">{{ room?.title }}</h2>
        <div class="viewer-count">
          <span>👁</span>
          <span>{{ viewerCount }}</span>
        </div>
      </div>
    </div>

    <div class="room-sidebar">
      <div class="sidebar-header">
        <div class="chat-title">💬 聊天</div>
      </div>
      
      <div class="chat-messages" ref="chatRef">
        <div v-for="msg in messages" :key="msg.id" class="chat-message" :class="msg.type">
          <span v-if="msg.type === 'danmaku'" class="danmaku">[弹幕]</span>
          <span v-if="msg.type === 'gift'" class="gift">[礼物]</span>
          <span v-if="msg.type === 'system'" class="system">[系统]</span>
          <span class="nickname">{{ msg.nickname }}:</span>
          <span class="content">{{ msg.content }}</span>
        </div>
      </div>

      <div v-if="activeGift" class="gift-animation">
        <div class="gift-item">
          <span class="gift-icon">{{ getGiftIcon(activeGift.giftIcon) }}</span>
          <span class="gift-name">{{ activeGift.giftName }}</span>
          <span class="gift-count">x{{ activeGift.count }}</span>
        </div>
      </div>

      <div class="sidebar-footer">
        <div class="gift-panel">
          <button 
            v-for="gift in gifts" 
            :key="gift.id" 
            class="gift-btn"
            @click="sendGift(gift)"
          >
            <span class="gift-icon">{{ getGiftIcon(gift.icon) }}</span>
            <span class="gift-name">{{ gift.name }}</span>
            <span class="gift-price">{{ gift.price }}</span>
          </button>
        </div>
        
        <div class="chat-input">
          <input 
            v-model="inputMessage" 
            placeholder="说点什么..."
            @keyup.enter="sendMessage"
          />
          <button class="send-btn" @click="sendMessage">发送</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick, watch } from 'vue'
import flvjs from 'flv.js'

const props = defineProps({
  roomId: { type: Number, required: true },
  userName: { type: String, default: '访客用户' }
})

defineEmits(['back'])

const videoRef = ref(null)
const chatRef = ref(null)
const room = ref(null)
const streamUrl = ref('')
const isPlaying = ref(false)
const viewerCount = ref(0)
const messages = ref([])
const gifts = ref([])
const inputMessage = ref('')
const activeGift = ref(null)

let ws = null
let flvPlayer = null
let reconnectTimer = null

const GIFT_ICONS = {
  heart: '❤️',
  lollipop: '🍭',
  cake: '🎂',
  car: '🚗',
  rocket: '🚀'
}

function getGiftIcon(icon) {
  return GIFT_ICONS[icon] || '🎁'
}

async function fetchRoom() {
  try {
    const res = await fetch(`/api/rooms/${props.roomId}`)
    const data = await res.json()
    if (data.success) {
      room.value = data.data
      // 如果是伪直播模式，获取视频URL
      if (data.data.fakeLive && data.data.isLive) {
        const streamRes = await fetch(`/api/rooms/${props.roomId}/stream-url`)
        const streamData = await streamRes.json()
        if (streamData.success && streamData.data.fakeLive) {
          streamUrl.value = streamData.data.videoUrl
          tryPlayFakeStream()
        }
      } else {
        streamUrl.value = data.data.streamUrl
        tryPlayStream()
      }
    }
  } catch (e) {
    console.error('获取直播间信息失败:', e)
  }
}

async function fetchGifts() {
  try {
    const res = await fetch('/api/gifts')
    const data = await res.json()
    if (data.success) {
      gifts.value = data.data
    }
  } catch (e) {
    console.error('获取礼物列表失败:', e)
  }
}

function tryPlayStream() {
  if (!streamUrl.value) return

  const flvUrl = streamUrl.value.replace('.mp4', '.flv').replace('localhost:8080', 'localhost:8080')
  
  // 如果有配置的流媒体地址，尝试播放
  if (flvjs.isSupported()) {
    if (flvPlayer) {
      flvPlayer.destroy()
    }
    flvPlayer = flvjs.createPlayer({
      type: 'flv',
      url: flvUrl,
      isLive: true
    })
    flvPlayer.attachMediaElement(videoRef.value)
    flvPlayer.load()
    flvPlayer.play().then(() => {
      isPlaying.value = true
    }).catch(() => {
      // 自动播放被阻止，等待用户交互
      videoRef.value?.addEventListener('click', () => {
        videoRef.value?.play()
      }, { once: true })
    })

    flvPlayer.on(flvjs.Events.ERROR, () => {
      isPlaying.value = false
      // 重试连接
      reconnectTimer = setTimeout(() => tryPlayStream(), 3000)
    })
  }
}

/**
 * 播放伪直播视频流（直接播放视频文件URL）
 */
function tryPlayFakeStream() {
  if (!streamUrl.value) return
  
  // 停止之前的FLV播放器
  if (flvPlayer) {
    flvPlayer.destroy()
    flvPlayer = null
  }
  
  // 直接使用video元素播放视频文件
  videoRef.value.src = streamUrl.value
  videoRef.value.play().then(() => {
    isPlaying.value = true
  }).catch(() => {
    // 自动播放被阻止，等待用户交互
    videoRef.value?.addEventListener('click', () => {
      videoRef.value?.play()
    }, { once: true })
  })
  
  // 监听视频结束事件，循环播放
  videoRef.value?.addEventListener('ended', () => {
    videoRef.value.currentTime = 0
    videoRef.value.play().catch(() => {})
  }, { once: false })
  
  // 监听错误事件
  videoRef.value?.addEventListener('error', () => {
    isPlaying.value = false
    reconnectTimer = setTimeout(() => tryPlayFakeStream(), 3000)
  }, { once: true })
}

function connectWebSocket() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const wsUrl = `${protocol}//localhost:3000?roomId=${props.roomId}`
  
  ws = new WebSocket(wsUrl)
  
  ws.onopen = () => {
    console.log('WebSocket 连接成功')
  }
  
  ws.onmessage = (event) => {
    try {
      const msg = JSON.parse(event.data)
      handleMessage(msg)
    } catch (e) {
      console.error('消息解析失败:', e)
    }
  }
  
  ws.onclose = () => {
    console.log('WebSocket 连接关闭')
    // 重连
    setTimeout(() => connectWebSocket(), 3000)
  }
}

function handleMessage(msg) {
  switch (msg.type) {
    case 'connected':
      viewerCount.value = msg.data.viewerCount
      break
    case 'system':
      addMessage({
        id: Date.now(),
        type: 'system',
        nickname: '系统',
        content: msg.data.message
      })
      viewerCount.value = msg.data.viewerCount
      break
    case 'danmaku':
      addMessage({
        id: msg.data.id,
        type: 'danmaku',
        nickname: msg.data.nickname,
        content: msg.data.content
      })
      break
    case 'gift':
      addMessage({
        id: Date.now(),
        type: 'gift',
        nickname: msg.data.nickname,
        content: `送出了 ${msg.data.giftName} x${msg.data.count}`
      })
      showGiftAnimation(msg.data)
      break
    case 'chat':
      addMessage({
        id: msg.data.id,
        type: 'chat',
        nickname: msg.data.nickname,
        content: msg.data.content
      })
      break
  }
}

function addMessage(msg) {
  messages.value.push(msg)
  if (messages.value.length > 100) {
    messages.value.shift()
  }
  nextTick(() => {
    if (chatRef.value) {
      chatRef.value.scrollTop = chatRef.value.scrollHeight
    }
  })
}

function showGiftAnimation(gift) {
  activeGift.value = gift
  setTimeout(() => {
    activeGift.value = null
  }, 3000)
}

function sendMessage() {
  if (!inputMessage.value.trim()) return
  
  const msg = {
    roomId: props.roomId,
    type: 'chat',
    content: inputMessage.value,
    nickname: props.userName
  }
  
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg))
  }
  
  addMessage({
    id: Date.now(),
    type: 'chat',
    nickname: props.userName,
    content: inputMessage.value
  })
  
  inputMessage.value = ''
}

function sendGift(gift) {
  const msg = {
    roomId: props.roomId,
    type: 'gift',
    giftId: gift.id,
    nickname: props.userName,
    count: 1
  }
  
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg))
  }
  
  // 本地先显示
  addMessage({
    id: Date.now(),
    type: 'gift',
    nickname: props.userName,
    content: `送出了 ${gift.name} x1`
  })
  showGiftAnimation({
    ...gift,
    count: 1
  })
}

onMounted(() => {
  fetchRoom()
  fetchGifts()
  connectWebSocket()
})

onUnmounted(() => {
  if (ws) ws.close()
  if (flvPlayer) flvPlayer.destroy()
  if (reconnectTimer) clearTimeout(reconnectTimer)
})
</script>

<style scoped>
.room-player {
  display: flex;
  height: calc(100vh - 60px);
  gap: 16px;
  padding: 16px;
}

.player-container {
  flex: 1;
  position: relative;
  background: #000;
  border-radius: 12px;
  overflow: hidden;
}

.video-player {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.player-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0,0,0,0.7);
}

.overlay-content {
  text-align: center;
  color: white;
}

.no-stream-text {
  font-size: 18px;
  margin-bottom: 12px;
}

.stream-url {
  font-size: 12px;
  color: #999;
  word-break: break-all;
}

.player-header {
  position: absolute;
  top: 12px;
  left: 12px;
  right: 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 16px;
  background: rgba(0,0,0,0.6);
  border-radius: 8px;
  color: white;
}

.back-btn {
  background: transparent;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 14px;
}

.room-title {
  font-size: 16px;
  font-weight: bold;
  flex: 1;
  text-align: center;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.viewer-count {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 14px;
}

.room-sidebar {
  width: 360px;
  display: flex;
  flex-direction: column;
  background: white;
  border-radius: 12px;
  overflow: hidden;
}

.sidebar-header {
  padding: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.chat-title {
  font-weight: bold;
  color: #333;
}

.chat-messages {
  flex: 1;
  padding: 12px 16px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.chat-message {
  font-size: 13px;
  line-height: 1.5;
}

.chat-message.danmaku .danmaku { color: #667eea; margin-right: 4px; }
.chat-message.gift .gift { color: #ffa500; margin-right: 4px; }
.chat-message.system .system { color: #999; margin-right: 4px; font-size: 12px; }

.nickname {
  color: #333;
  font-weight: 500;
  margin-right: 4px;
}

.chat-message.system .content { color: #999; font-size: 12px; }

.gift-animation {
  position: absolute;
  bottom: 200px;
  right: 400px;
  pointer-events: none;
  animation: giftFloat 3s ease-out forwards;
}

@keyframes giftFloat {
  0% { transform: translateY(0) scale(1); opacity: 1; }
  100% { transform: translateY(-200px) scale(1.5); opacity: 0; }
}

.gift-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 20px;
  background: linear-gradient(135deg, #ffa500 0%, #ff6347 100%);
  border-radius: 24px;
  color: white;
  font-size: 16px;
  font-weight: bold;
  box-shadow: 0 4px 20px rgba(255,165,0,0.4);
}

.gift-item .gift-icon { font-size: 24px; }
.gift-item .gift-count { font-size: 20px; }

.sidebar-footer {
  border-top: 1px solid #f0f0f0;
  padding: 12px 16px;
}

.gift-panel {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.gift-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 12px;
  background: #f8f8f8;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 12px;
}

.gift-btn:hover {
  background: #f0f0f0;
  transform: translateY(-2px);
}

.gift-btn .gift-icon { font-size: 20px; }
.gift-btn .gift-price { color: #ffa500; font-weight: bold; }

.chat-input {
  display: flex;
  gap: 8px;
}

.chat-input input {
  flex: 1;
  padding: 10px 12px;
  border: 1px solid #e0e0e0;
  border-radius: 20px;
  font-size: 14px;
  outline: none;
}

.chat-input input:focus {
  border-color: #667eea;
}

.send-btn {
  padding: 0 20px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 20px;
  cursor: pointer;
  font-size: 14px;
}

.send-btn:hover { opacity: 0.9; }
</style>
