<template>
  <div class="mobile-room-player" :class="{ 'landscape-mode': videoOrientation === 'landscape', 'portrait-mode': videoOrientation === 'portrait' }">
    <!-- 全屏视频播放区 -->
    <div class="player-area" :class="{ 'landscape-video': videoOrientation === 'landscape', 'portrait-video': videoOrientation === 'portrait' }">
      <video 
        ref="videoRef" 
        class="video-player"
        :class="{ 'landscape-video': videoOrientation === 'landscape', 'portrait-video': videoOrientation === 'portrait' }"
        autoplay 
        playsinline
        webkit-playsinline="true"
        :muted="isMuted"
        @loadedmetadata="onVideoLoaded"
        @error="onVideoError"
      ></video>
      
      <!-- 视频方向指示器 -->
      <div v-if="videoOrientation" class="orientation-indicator" :class="videoOrientation">
        <span class="orientation-icon">{{ videoOrientation === 'landscape' ? '⇆' : '⇅' }}</span>
      </div>
      
      <!-- 视频遮罩层 -->
      <div v-if="!isPlaying" class="player-overlay">
        <div class="overlay-content">
          <div class="play-icon" @click="playVideo">▶</div>
          <p class="no-stream-text">
            {{ isLive ? '正在连接直播...' : '主播未开播' }}
          </p>
        </div>
      </div>

      <!-- 顶部信息栏（浮在视频上方） -->
      <div class="top-info-bar">
        <div class="streamer-info">
          <div class="streamer-avatar">
            <img v-if="room?.cover" :src="room.cover" />
            <span v-else class="avatar-text">{{ room?.title?.charAt(0) || '主' }}</span>
          </div>
          <div class="streamer-detail">
            <div class="streamer-name">{{ room?.title }}</div>
            <div class="streamer-stats">
              <span class="live-tag" v-if="isLive">
                <span class="live-dot"></span>
                直播中
              </span>
              <span class="viewer-count">
                <span class="eye-icon">👁</span>
                {{ viewerCount }}
              </span>
            </div>
          </div>
          <button class="follow-btn" @click="handleFollow">关注</button>
        </div>
      </div>

      <!-- 弹幕浮层（视频中间区域） -->
      <div class="danmaku-layer">
        <div 
          v-for="msg in visibleDanmaku" 
          :key="msg.id" 
          class="danmaku-item"
          :style="{ animationDelay: msg.delay + 's' }"
        >
          <span class="danmaku-nickname" :style="{ color: msg.color }">{{ msg.nickname }}:</span>
          <span class="danmaku-content">{{ msg.content }}</span>
        </div>
      </div>

      <!-- 礼物动画 -->
      <div v-if="activeGift" class="gift-animation">
        <div class="gift-item">
          <span class="gift-icon">{{ getGiftIcon(activeGift.giftIcon) }}</span>
          <span class="gift-name">{{ activeGift.giftName }}</span>
          <span class="gift-count">x{{ activeGift.count }}</span>
        </div>
      </div>

      <!-- 聊天消息浮层（视频左下区域） -->
      <div class="chat-float-layer">
        <div v-for="msg in recentMessages" :key="msg.id" class="chat-float-item" :class="msg.type">
          <span v-if="msg.type === 'danmaku'" class="float-tag danmaku-tag">弹幕</span>
          <span v-if="msg.type === 'gift'" class="float-tag gift-tag">礼物</span>
          <span v-if="msg.type === 'system'" class="float-tag system-tag">系统</span>
          <span class="float-nickname" :style="{ color: msg.color || '#fff' }">{{ msg.nickname }}:</span>
          <span class="float-content">{{ msg.content }}</span>
        </div>
      </div>

      <!-- 右侧操作按钮栏 -->
      <div class="side-actions">
        <div class="side-btn" @click="toggleMute">
          <span class="side-icon">{{ isMuted ? '🔇' : '🔊' }}</span>
          <span class="side-label">{{ isMuted ? '开声' : '静音' }}</span>
        </div>
        <div class="side-btn" @click="showGiftPanel = true">
          <span class="side-icon">🎁</span>
          <span class="side-label">礼物</span>
        </div>
        <div class="side-btn" @click="scrollChatToBottom">
          <span class="side-icon">💬</span>
          <span class="side-label">聊天</span>
        </div>
      </div>
    </div>

    <!-- 底部操作栏 -->
    <div class="bottom-bar">
      <div class="action-row">
        <div 
          v-for="gift in visibleGifts" 
          :key="gift.id" 
          class="gift-quick-btn"
          @click="sendGift(gift)"
        >
          <span class="gift-emoji">{{ getGiftIcon(gift.icon) }}</span>
          <span class="gift-price">{{ gift.price }}</span>
        </div>
      </div>
      
      <div class="input-row">
        <input 
          v-model="inputMessage" 
          class="chat-input"
          placeholder="说点什么..."
          @keyup.enter="sendMessage"
        />
        <button 
          class="send-btn" 
          :disabled="!inputMessage.trim()"
          @click="sendMessage"
        >
          发送
        </button>
      </div>
    </div>

    <!-- 礼物选择弹窗 -->
    <div v-if="showGiftPanel" class="gift-panel-modal" @click.self="showGiftPanel = false">
      <div class="gift-panel">
        <div class="panel-header">
          <span>选择礼物</span>
          <span class="close-btn" @click="showGiftPanel = false">×</span>
        </div>
        <div class="gift-grid">
          <div 
            v-for="gift in gifts" 
            :key="gift.id" 
            class="gift-item-cell"
            @click="sendGift(gift)"
          >
            <span class="gift-emoji-lg">{{ getGiftIcon(gift.icon) }}</span>
            <span class="gift-name-sm">{{ gift.name }}</span>
            <span class="gift-price-sm">{{ gift.price }}币</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 完整聊天面板 -->
    <div v-if="showChatPanel" class="chat-panel-modal" @click.self="showChatPanel = false">
      <div class="chat-panel">
        <div class="chat-panel-header">
          <span>聊天</span>
          <span class="close-btn" @click="showChatPanel = false">×</span>
        </div>
        <div class="chat-panel-messages" ref="chatRef">
          <div v-for="msg in messages" :key="msg.id" class="chat-panel-msg" :class="msg.type">
            <span v-if="msg.type === 'danmaku'" class="panel-tag danmaku-tag">[弹幕]</span>
            <span v-if="msg.type === 'gift'" class="panel-tag gift-tag">[礼物]</span>
            <span v-if="msg.type === 'system'" class="panel-tag system-tag">[系统]</span>
            <span class="panel-nickname" :style="{ color: msg.color || '#333' }">{{ msg.nickname }}:</span>
            <span class="panel-content">{{ msg.content }}</span>
          </div>
          <div v-if="messages.length === 0" class="no-messages">
            <p>暂无聊天消息，快来发送第一条吧~</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 弹窗图片组件 -->
    <transition name="popup-fade">
      <div v-if="showPopup" class="popup-overlay" @click="closePopup">
        <div class="popup-container" @click.stop>
          <img 
            v-if="popupConfig.image" 
            :src="popupConfig.image.url" 
            :alt="popupConfig.image.name"
            class="popup-image"
            @click="openFullscreen"
          />
          <div class="popup-close" @click="closePopup">×</div>
          <div class="popup-timer" v-if="popupCountdown > 0">
            {{ popupCountdown }} 秒后自动关闭
          </div>
        </div>
      </div>
    </transition>

    <!-- 全屏预览弹窗 -->
    <transition name="popup-fade">
      <div v-if="showFullscreenPopup" class="fullscreen-popup" @click="showFullscreenPopup = false">
        <img 
          v-if="popupConfig.image" 
          :src="popupConfig.image.url" 
          :alt="popupConfig.image.name"
        />
        <div class="popup-close" @click="showFullscreenPopup = false">×</div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick, computed } from 'vue'
import flvjs from 'flv.js'
import Hls from 'hls.js'

const props = defineProps({
  roomId: { type: Number, required: true },
  userName: { type: String, default: '访客用户' }
})

defineEmits(['back'])

const videoRef = ref(null)
const chatRef = ref(null)
const room = ref(null)
const isPlaying = ref(false)
const isLive = ref(false)
const isMuted = ref(false)
const viewerCount = ref(0)
const messages = ref([])
const gifts = ref([])
const inputMessage = ref('')
const activeGift = ref(null)
const showGiftPanel = ref(false)
const showChatPanel = ref(false)

// 弹窗图片相关
const popupConfig = ref({
  popupId: null,
  enabled: false,
  displayDuration: 5,
  delayTime: 3,
  image: null
})
const showPopup = ref(false)
const showFullscreenPopup = ref(false)
const popupCountdown = ref(0)
let popupTimer = null
let countdownTimer = null

// 视频方向：'landscape' 横屏, 'portrait' 竖屏
const videoOrientation = ref('landscape')

// 弹幕浮层数据
const visibleDanmaku = ref([])
let danmakuId = 0

// 常用礼物（前3个）
const visibleGifts = ref([])

// 最近的聊天消息（用于浮层显示）
const recentMessages = computed(() => {
  return messages.value.slice(-5)
})

const GIFT_ICONS = {
  heart: '❤️',
  lollipop: '🍭',
  cake: '🎂',
  car: '🚗',
  rocket: '🚀'
}

let ws = null
let flvPlayer = null
let hlsPlayer = null
let reconnectTimer = null
let chatScrollTimer = null
const currentLiveMode = ref('normal') // normal: 正常直播, fake: 伪直播
let currentHlsUrl = '' // 保存当前HLS地址用于降级

function getGiftIcon(icon) {
  return GIFT_ICONS[icon] || '🎁'
}

function handleFollow() {
  alert('关注成功!')
}

async function fetchRoom() {
  try {
    const res = await fetch(`/api/rooms/${props.roomId}`)
    const data = await res.json()
    if (data.success) {
      room.value = data.data
      isLive.value = data.data.isLive
      
      // 获取直播流地址
      const streamRes = await fetch(`/api/rooms/${props.roomId}/stream-url`)
      const streamData = await streamRes.json()
      
      if (streamData.success) {
        currentLiveMode.value = streamData.data.liveMode || 'normal'
        
        if (streamData.data.liveMode === 'fake') {
          // 伪直播模式
          if (streamData.data.videoUrl && isLive.value) {
            playFakeLive(streamData.data.videoUrl)
          }
        } else {
          // 正常直播模式
          if (isLive.value) {
            playNormalLive(streamData.data.flvUrl, streamData.data.hlsUrl)
          }
        }
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
      // 取前3个作为快捷礼物
      visibleGifts.value = data.data.slice(0, 3)
    }
  } catch (e) {
    console.error('获取礼物列表失败:', e)
  }
}

/**
 * 播放伪直播（循环播放视频文件）
 */
function playFakeLive(url) {
  if (!url || !videoRef.value) return
  
  destroyAllPlayers()
  
  videoRef.value.src = url
  videoRef.value.play().then(() => {
    isPlaying.value = true
  }).catch(() => {
    isPlaying.value = false
  })
  
  // 循环播放
  videoRef.value.onended = () => {
    videoRef.value.currentTime = 0
    videoRef.value.play().catch(() => {})
  }
}

/**
 * 播放正常直播流
 */
function playNormalLive(flvUrl, hlsUrl) {
  if (!videoRef.value) return
  
  currentHlsUrl = hlsUrl || ''
  destroyAllPlayers()
  
  // 优先尝试FLV播放（低延迟）
  if (flvUrl && flvjs.isSupported()) {
    playByFlv(flvUrl)
  } else if (hlsUrl && Hls.isSupported()) {
    // 降级到HLS
    playByHls(hlsUrl)
  } else if (hlsUrl && videoRef.value.canPlayType('application/vnd.apple.mpegurl')) {
    // Safari原生支持HLS
    videoRef.value.src = hlsUrl
    videoRef.value.play().then(() => {
      isPlaying.value = true
    }).catch(() => {
      isPlaying.value = false
    })
  } else {
    console.error('当前浏览器不支持任何直播播放方式')
  }
}

/**
 * 使用flv.js播放
 */
function playByFlv(url) {
  if (!flvjs.isSupported()) return false
  
  flvPlayer = flvjs.createPlayer({
    type: 'live',
    url: url,
    isLive: true,
    hasAudio: true,
    hasVideo: true
  })
  
  flvPlayer.attachMediaElement(videoRef.value)
  flvPlayer.load()
  flvPlayer.play().then(() => {
    isPlaying.value = true
  }).catch((err) => {
    console.error('FLV播放失败:', err)
    // 降级到HLS
    if (currentHlsUrl && Hls.isSupported()) {
      playByHls(currentHlsUrl)
    }
  })
  
  flvPlayer.on(flvjs.Events.ERROR, (errorType, errorDetail) => {
    console.error('FLV错误:', errorType, errorDetail)
    isPlaying.value = false
  })
  
  flvPlayer.on(flvjs.Events.LOADING_COMPLETE, () => {
    if (isLive.value) {
      reconnectFlv(url)
    }
  })
  
  return true
}

/**
 * 使用hls.js播放
 */
function playByHls(url) {
  if (!Hls.isSupported()) return false
  
  hlsPlayer = new Hls({
    enableWorker: true,
    lowLatencyMode: true,
    liveSyncDurationCount: 3,
    enableStashBuffer: false
  })
  
  hlsPlayer.loadSource(url)
  hlsPlayer.attachMedia(videoRef.value)
  
  hlsPlayer.on(Hls.Events.MANIFEST_PARSED, () => {
    videoRef.value.play().then(() => {
      isPlaying.value = true
    }).catch(() => {
      isPlaying.value = false
    })
  })
  
  hlsPlayer.on(Hls.Events.ERROR, (event, data) => {
    if (data.fatal) {
      console.error('HLS致命错误:', data.type, data.details)
      
      switch (data.type) {
        case Hls.ErrorTypes.NETWORK_ERROR:
          hlsPlayer.startLoad()
          break
        case Hls.ErrorTypes.MEDIA_ERROR:
          hlsPlayer.recoverMediaError()
          break
        default:
          hlsPlayer.destroy()
          break
      }
    }
  })
  
  return true
}

/**
 * FLV重连
 */
function reconnectFlv(url) {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer)
  }
  
  reconnectTimer = setTimeout(() => {
    if (flvPlayer) {
      flvPlayer.unload()
      flvPlayer.load()
      flvPlayer.play().catch(() => {
        if (currentHlsUrl && Hls.isSupported()) {
          playByHls(currentHlsUrl)
        }
      })
    }
  }, 3000)
}

/**
 * 销毁所有播放器实例
 */
function destroyAllPlayers() {
  if (flvPlayer) {
    flvPlayer.pause()
    flvPlayer.unload()
    flvPlayer.detachMediaElement()
    flvPlayer.destroy()
    flvPlayer = null
  }
  
  if (hlsPlayer) {
    hlsPlayer.destroy()
    hlsPlayer = null
  }
  
  if (reconnectTimer) {
    clearTimeout(reconnectTimer)
    reconnectTimer = null
  }
}

// 视频元数据加载完成，检测横竖屏
function onVideoLoaded() {
  if (!videoRef.value) return
  
  const videoWidth = videoRef.value.videoWidth
  const videoHeight = videoRef.value.videoHeight
  
  if (videoWidth > 0 && videoHeight > 0) {
    // 宽高比大于1为横屏，否则为竖屏
    const newOrientation = videoWidth > videoHeight ? 'landscape' : 'portrait'
    
    // 只有当方向改变时才更新，避免不必要的重渲染
    if (videoOrientation.value !== newOrientation) {
      videoOrientation.value = newOrientation
      console.log(`视频方向检测: ${videoOrientation.value}, 尺寸: ${videoWidth}x${videoHeight}`)
      
      // 横屏模式下尝试横屏播放（移动端支持）
      if (newOrientation === 'landscape') {
        attemptLandscapePlay()
      }
    }
  }
}

// 视频错误处理
function onVideoError(e) {
  console.error('视频加载错误:', e)
  isPlaying.value = false
}

// 尝试横屏播放
function attemptLandscapePlay() {
  // 检测是否支持屏幕方向API
  if (screen.orientation && screen.orientation.lock) {
    try {
      // 尝试锁定横屏方向（需要全屏状态）
      screen.orientation.lock('landscape').catch(() => {
        // 锁定失败（可能需要用户手势），保持竖屏显示
        console.log('无法锁定屏幕方向，保持竖屏显示横屏视频')
      })
    } catch (e) {
      console.log('屏幕方向API不可用')
    }
  }
}

function playVideo() {
  if (!videoRef.value) return
  
  if (videoRef.value.paused) {
    videoRef.value.play().then(() => {
      isPlaying.value = true
    }).catch(() => {})
  }
}

function toggleMute() {
  isMuted.value = !isMuted.value
  if (videoRef.value) {
    videoRef.value.muted = isMuted.value
  }
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
    // 自动重连
    setTimeout(() => connectWebSocket(), 3000)
  }
  
  ws.onerror = () => {
    ws.close()
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
        content: msg.data.message,
        color: '#999'
      })
      viewerCount.value = msg.data.viewerCount
      break
    case 'danmaku':
      addMessage({
        id: msg.data.id,
        type: 'danmaku',
        nickname: msg.data.nickname,
        content: msg.data.content,
        color: msg.data.color
      })
      addDanmakuToLayer({
        id: msg.data.id,
        nickname: msg.data.nickname,
        content: msg.data.content,
        color: msg.data.color
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
    case 'popup':
      // 实时弹窗消息处理
      handlePopupMessage(msg.data)
      break
  }
}

/**
 * 处理弹窗消息（实时或定时触发）
 */
function handlePopupMessage(data) {
  // 更新弹窗配置
  popupConfig.value = {
    popupId: data.image?.id || null,
    enabled: true,
    displayDuration: data.displayDuration || 5,
    delayTime: 0,
    image: data.image
  }
  
  // 显示弹窗
  if (data.image) {
    showPopupImage()
  }
}

function addMessage(msg) {
  messages.value.push(msg)
  if (messages.value.length > 100) {
    messages.value.shift()
  }
  
  if (showChatPanel.value) {
    nextTick(() => {
      scrollChatToBottom()
    })
  }
}

function scrollChatToBottom() {
  if (chatRef.value) {
    chatRef.value.scrollTop = chatRef.value.scrollHeight
  }
}

function addDanmakuToLayer(msg) {
  const delay = Math.random() * 2
  const danmaku = {
    ...msg,
    id: ++danmakuId,
    delay
  }
  
  visibleDanmaku.value.push(danmaku)
  
  // 3秒后移除
  setTimeout(() => {
    const idx = visibleDanmaku.value.findIndex(d => d.id === danmaku.id)
    if (idx !== -1) {
      visibleDanmaku.value.splice(idx, 1)
    }
  }, 3000)
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

// 加载弹窗配置
async function fetchPopupConfig() {
  try {
    const res = await fetch(`/api/rooms/${props.roomId}/popup`)
    const data = await res.json()
    if (data.success) {
      popupConfig.value = data.data
      
      // 如果启用了弹窗，设置延迟显示
      if (data.data.enabled && data.data.image) {
        schedulePopup()
      }
    }
  } catch (e) {
    console.error('加载弹窗配置失败:', e)
  }
}

// 延迟显示弹窗
function schedulePopup() {
  const delay = (popupConfig.value.delayTime || 3) * 1000
  popupTimer = setTimeout(() => {
    showPopupImage()
  }, delay)
}

// 显示弹窗图片
function showPopupImage() {
  if (!popupConfig.value.image || !popupConfig.value.enabled) return
  
  showPopup.value = true
  popupCountdown.value = popupConfig.value.displayDuration || 5
  
  // 倒计时
  countdownTimer = setInterval(() => {
    popupCountdown.value--
    if (popupCountdown.value <= 0) {
      closePopup()
    }
  }, 1000)
}

// 关闭弹窗
function closePopup() {
  showPopup.value = false
  if (countdownTimer) {
    clearInterval(countdownTimer)
    countdownTimer = null
  }
  popupCountdown.value = 0
}

// 全屏预览
function openFullscreen() {
  showFullscreenPopup.value = true
}

onMounted(() => {
  fetchRoom()
  fetchGifts()
  fetchPopupConfig()
  connectWebSocket()
  
  // 页面隐藏时暂停视频
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && videoRef.value) {
      videoRef.value.pause()
      isPlaying.value = false
    }
  })
})

onUnmounted(() => {
  if (ws) ws.close()
  if (flvPlayer) flvPlayer.destroy()
  if (reconnectTimer) clearTimeout(reconnectTimer)
  if (chatScrollTimer) clearTimeout(chatScrollTimer)
  if (popupTimer) clearTimeout(popupTimer)
  if (countdownTimer) clearInterval(countdownTimer)
  if (videoRef.value) {
    videoRef.value.pause()
    videoRef.value.src = ''
  }
})
</script>

<style scoped>
/* ============================================
   Stitch 设计系统 - CSS 变量
   ============================================ */
:root {
  --stitch-primary: #3953bd;
  --stitch-primary-container: #546cd7;
  --stitch-primary-fixed: #dde1ff;
  --stitch-primary-fixed-dim: #b9c3ff;
  --stitch-on-primary: #ffffff;
  
  --stitch-secondary: #b9082c;
  --stitch-secondary-container: #dd2d42;
  --stitch-secondary-fixed: #ffdad9;
  --stitch-secondary-fixed-dim: #ffb3b2;
  
  --stitch-tertiary: #705d00;
  --stitch-tertiary-container: #c9a900;
  --stitch-tertiary-fixed: #ffe16d;
  --stitch-tertiary-fixed-dim: #e9c400;
  
  --stitch-background: #f8f9fc;
  --stitch-surface: #f8f9fc;
  --stitch-surface-container: #edeef1;
  --stitch-surface-container-low: #f2f3f6;
  --stitch-surface-container-high: #e7e8eb;
  --stitch-surface-variant: #e1e2e5;
  --stitch-on-surface: #191c1e;
  --stitch-on-surface-variant: #444653;
  --stitch-outline-variant: #c5c5d5;
  
  --stitch-gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  --stitch-gradient-gold: linear-gradient(135deg, #ffd700 0%, #ffa500 100%);
  
  --stitch-radius-sm: 4px;
  --stitch-radius-md: 8px;
  --stitch-radius-lg: 12px;
  --stitch-radius-xl: 16px;
  --stitch-radius-full: 9999px;
  
  --stitch-safe-top: env(safe-area-inset-top, 0px);
  --stitch-safe-bottom: env(safe-area-inset-bottom, 0px);
}

/* ============================================
   基础布局
   ============================================ */
.mobile-room-player {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 50px);
  background: #000;
  overflow: hidden;
}

.player-area {
  position: relative;
  flex: 1;
  width: 100%;
  background: #000;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
}

.player-area.landscape-video {
  background: #000;
}

.player-area.landscape-video .video-player.landscape-video {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.player-area.portrait-video {
  background: #000;
}

.player-area.portrait-video .video-player.portrait-video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* 横屏模式 */
.mobile-room-player.landscape-mode {
  height: 100vh;
}

.mobile-room-player.landscape-mode .player-area {
  flex-direction: row;
}

.mobile-room-player.landscape-mode .bottom-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 30;
}

.mobile-room-player.landscape-mode .danmaku-layer {
  top: 60px;
  bottom: 100px;
}

.mobile-room-player.landscape-mode .side-actions {
  right: 16px;
  bottom: 100px;
}

.mobile-room-player.landscape-mode .chat-float-layer {
  bottom: 100px;
  left: 16px;
}

.mobile-room-player.landscape-mode .gift-animation {
  bottom: 120px;
  right: 90px;
}

.video-player {
  background: #000;
  transition: object-fit 0.3s ease;
}

/* 方向指示器 */
.orientation-indicator {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 80px;
  height: 80px;
  background: rgba(0, 0, 0, 0.7);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  animation: orientationFadeOut 2s forwards;
  pointer-events: none;
}

.orientation-indicator.landscape .orientation-icon,
.orientation-indicator.portrait .orientation-icon {
  font-size: 36px;
  color: #fff;
}

@keyframes orientationFadeOut {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.5); }
  20% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
  80% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
  100% { opacity: 0; transform: translate(-50%, -50%) scale(1.2); }
}

/* 播放覆盖层 */
.player-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.7);
  color: white;
  z-index: 10;
}

.play-icon {
  width: 70px;
  height: 70px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  font-size: 28px;
  cursor: pointer;
  margin-bottom: 12px;
}

.no-stream-text {
  font-size: 15px;
}

/* ============================================
   顶部信息栏 - 毛玻璃
   ============================================ */
.top-info-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  padding: 14px 16px;
  padding-top: calc(14px + var(--stitch-safe-top));
  background: linear-gradient(180deg, rgba(0,0,0,0.7) 0%, rgba(0,0,0,0.3) 60%, transparent 100%);
  z-index: 20;
  pointer-events: none;
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.streamer-info {
  display: flex;
  align-items: center;
  gap: 12px;
  pointer-events: auto;
}

.streamer-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  overflow: hidden;
  border: 2px solid var(--stitch-primary-fixed);
  background: #333;
  flex-shrink: 0;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
}

.streamer-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-text {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--stitch-gradient-primary);
  color: white;
  font-size: 20px;
  font-weight: bold;
}

.streamer-detail {
  flex: 1;
  min-width: 0;
}

.streamer-name {
  font-size: 15px;
  font-weight: 600;
  color: white;
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.5);
}

.streamer-stats {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.9);
}

/* LIVE标签 - Stitch脉冲环动画 */
.live-tag {
  display: flex;
  align-items: center;
  gap: 4px;
  background: rgba(255, 71, 87, 0.9);
  padding: 3px 10px;
  border-radius: var(--stitch-radius-full);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  box-shadow: 0 0 0 0 rgba(255, 71, 87, 0.7);
  animation: stitchLivePulse 2s infinite cubic-bezier(0.215, 0.61, 0.355, 1);
}

@keyframes stitchLivePulse {
  0% { box-shadow: 0 0 0 0 rgba(255, 71, 87, 0.7); }
  70% { box-shadow: 0 0 0 6px rgba(255, 71, 87, 0); }
  100% { box-shadow: 0 0 0 0 rgba(255, 71, 87, 0); }
}

.live-dot {
  width: 6px;
  height: 6px;
  background: white;
  border-radius: 50%;
  animation: stitchDotPulse 1s infinite;
}

@keyframes stitchDotPulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.6; transform: scale(0.8); }
}

.viewer-count {
  display: flex;
  align-items: center;
  gap: 5px;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  padding: 3px 10px;
  border-radius: var(--stitch-radius-full);
  font-weight: 700;
}

.eye-icon {
  font-size: 12px;
}

/* 关注按钮 - CTA渐变 */
.follow-btn {
  padding: 8px 18px;
  background: var(--stitch-gradient-primary);
  color: white;
  border: none;
  border-radius: var(--stitch-radius-full);
  font-size: 13px;
  cursor: pointer;
  font-weight: 700;
  flex-shrink: 0;
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.4);
  transition: all 0.3s ease;
}

.follow-btn:active {
  transform: scale(0.95);
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

/* ============================================
   弹幕浮层
   ============================================ */
.danmaku-layer {
  position: absolute;
  left: 0;
  right: 80px;
  top: 120px;
  bottom: 220px;
  pointer-events: none;
  overflow: hidden;
  z-index: 15;
}

.danmaku-item {
  position: absolute;
  left: 100%;
  white-space: nowrap;
  animation: stitchDanmakuScroll 6s linear forwards;
  font-size: 16px;
  text-shadow: 2px 2px 6px rgba(0, 0, 0, 0.95), 0 0 3px rgba(0, 0, 0, 0.8);
  margin-bottom: 12px;
  font-weight: 500;
}

@keyframes stitchDanmakuScroll {
  from { transform: translateX(0); }
  to { transform: translateX(calc(-100% - 100vw)); }
}

.danmaku-nickname {
  font-weight: 600;
  margin-right: 4px;
  text-shadow: 1px 1px 4px rgba(0, 0, 0, 0.8);
}

.danmaku-content {
  color: white;
}

/* ============================================
   礼物动画 - 上浮效果
   ============================================ */
.gift-animation {
  position: absolute;
  bottom: 200px;
  right: 90px;
  pointer-events: none;
  animation: stitchGiftFloat 3s ease-out forwards;
  z-index: 25;
}

@keyframes stitchGiftFloat {
  0% { transform: translateY(0) scale(0.8); opacity: 0; }
  20% { transform: translateY(-20px) scale(1.1); opacity: 1; }
  100% { transform: translateY(-220px) scale(1.4); opacity: 0; }
}

.gift-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 24px;
  background: linear-gradient(135deg, #ffa500 0%, #ff6347 50%, #ff4757 100%);
  background-size: 200% 200%;
  animation: giftShine 2s ease infinite;
  border-radius: 28px;
  color: white;
  font-size: 16px;
  font-weight: bold;
  box-shadow: 0 8px 32px rgba(255, 165, 0, 0.5);
}

@keyframes giftShine {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

.gift-icon {
  font-size: 28px;
  animation: giftBounce 0.5s ease infinite alternate;
}

@keyframes giftBounce {
  from { transform: scale(1); }
  to { transform: scale(1.2); }
}

/* ============================================
   聊天消息浮层 - 毛玻璃
   ============================================ */
.chat-float-layer {
  position: absolute;
  left: 14px;
  bottom: 200px;
  max-width: 260px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 15;
  pointer-events: none;
}

.chat-float-item {
  background: rgba(25, 28, 30, 0.4);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  padding: 8px 12px;
  border-radius: var(--stitch-radius-lg);
  font-size: 13px;
  color: white;
  line-height: 1.5;
  animation: stitchFloatMsgIn 0.35s ease-out;
  max-width: 100%;
}

@keyframes stitchFloatMsgIn {
  from { opacity: 0; transform: translateY(12px) scale(0.95); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

.float-tag {
  display: inline-block;
  font-size: 10px;
  padding: 1px 5px;
  border-radius: var(--stitch-radius-sm);
  margin-right: 4px;
}

.danmaku-tag {
  background: rgba(102, 126, 234, 0.3);
  color: #a5b4fc;
}

.gift-tag {
  background: rgba(255, 165, 0, 0.3);
  color: #ffd700;
}

.system-tag {
  background: rgba(153, 153, 153, 0.3);
  color: #ccc;
}

.float-nickname {
  font-weight: 600;
  margin-right: 4px;
}

.float-content {
  color: white;
}

/* ============================================
   右侧操作按钮 - 毛玻璃圆形
   ============================================ */
.side-actions {
  position: absolute;
  right: 12px;
  bottom: 200px;
  display: flex;
  flex-direction: column;
  gap: 18px;
  z-index: 20;
}

.side-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  cursor: pointer;
  color: white;
  transition: transform 0.2s ease;
}

.side-btn:active {
  transform: scale(0.9);
}

.side-icon {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(25, 28, 30, 0.4);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 50%;
  font-size: 20px;
  transition: all 0.3s ease;
}

.side-btn:active .side-icon {
  background: rgba(102, 126, 234, 0.6);
  border-color: var(--stitch-primary-fixed-dim);
}

.side-label {
  font-size: 11px;
  text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.9);
  font-weight: 500;
}

/* ============================================
   底部操作栏 - 毛玻璃
   ============================================ */
.bottom-bar {
  background: linear-gradient(180deg, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0.85) 100%);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  padding: 12px 14px;
  padding-bottom: calc(12px + var(--stitch-safe-bottom));
  z-index: 30;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

.action-row {
  display: flex;
  gap: 14px;
  margin-bottom: 10px;
  justify-content: center;
}

.gift-quick-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  cursor: pointer;
  padding: 8px 14px;
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border-radius: var(--stitch-radius-lg);
  transition: all 0.3s ease;
  border: 1px solid rgba(255, 255, 255, 0.05);
}

.gift-quick-btn:active {
  background: rgba(255, 255, 255, 0.15);
  transform: scale(0.95);
}

.gift-emoji {
  font-size: 26px;
}

.gift-price {
  font-size: 12px;
  color: var(--stitch-tertiary-fixed);
  font-weight: 700;
}

.input-row {
  display: flex;
  gap: 10px;
}

.chat-input {
  flex: 1;
  padding: 12px 16px;
  background: rgba(25, 28, 30, 0.4);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: var(--stitch-radius-full);
  font-size: 14px;
  color: white;
  outline: none;
  transition: all 0.3s ease;
}

.chat-input::placeholder {
  color: rgba(255, 255, 255, 0.5);
}

.chat-input:focus {
  background: rgba(25, 28, 30, 0.6);
  border-color: var(--stitch-primary-fixed-dim);
  box-shadow: 0 0 0 2px rgba(185, 195, 255, 0.3);
}

.send-btn {
  padding: 12px 26px;
  background: var(--stitch-gradient-primary);
  color: white;
  border: none;
  border-radius: var(--stitch-radius-full);
  font-size: 14px;
  cursor: pointer;
  font-weight: 700;
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.4);
  transition: all 0.3s ease;
}

.send-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
  box-shadow: none;
}

.send-btn:not(:disabled):active {
  transform: scale(0.96);
}

/* ============================================
   礼物选择弹窗
   ============================================ */
.gift-panel-modal {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
}

.gift-panel {
  width: 100%;
  background: white;
  border-radius: 20px 20px 0 0;
  padding: 16px;
  padding-bottom: calc(16px + var(--stitch-safe-bottom));
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  font-size: 16px;
  font-weight: 600;
  color: var(--stitch-on-surface);
}

.close-btn {
  font-size: 28px;
  color: var(--stitch-outline);
  cursor: pointer;
  line-height: 1;
}

.gift-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

.gift-item-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 14px 8px;
  background: var(--stitch-surface-container-low);
  border-radius: var(--stitch-radius-lg);
  cursor: pointer;
  transition: all 0.2s;
}

.gift-item-cell:active {
  background: var(--stitch-surface-container);
  transform: scale(0.95);
}

.gift-emoji-lg {
  font-size: 36px;
  margin-bottom: 6px;
}

.gift-name-sm {
  font-size: 13px;
  color: var(--stitch-on-surface);
  margin-bottom: 2px;
}

.gift-price-sm {
  font-size: 12px;
  color: #ffa500;
  font-weight: 600;
}

/* ============================================
   聊天面板
   ============================================ */
.chat-panel-modal {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
}

.chat-panel {
  width: 100%;
  max-height: 70vh;
  background: white;
  border-radius: 20px 20px 0 0;
  display: flex;
  flex-direction: column;
}

.chat-panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  font-size: 16px;
  font-weight: 600;
  color: var(--stitch-on-surface);
  border-bottom: 1px solid var(--stitch-surface-container);
}

.chat-panel-messages {
  flex: 1;
  padding: 12px 16px;
  overflow-y: auto;
  max-height: 50vh;
}

.chat-panel-msg {
  font-size: 14px;
  line-height: 1.6;
  padding: 6px 0;
  color: var(--stitch-on-surface);
}

.panel-tag {
  font-size: 11px;
  margin-right: 4px;
}

.panel-nickname {
  font-weight: 500;
  margin-right: 4px;
}

.no-messages {
  text-align: center;
  padding: 30px;
  color: var(--stitch-outline);
  font-size: 14px;
}

/* ============================================
   弹窗图片样式
   ============================================ */

.popup-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.85);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
}

.popup-container {
  position: relative;
  max-width: 90vw;
  max-height: 80vh;
  border-radius: 16px;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
}

.popup-image {
  display: block;
  max-width: 90vw;
  max-height: 80vh;
  width: auto;
  height: auto;
  object-fit: contain;
  border-radius: 16px;
}

.popup-close {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 36px;
  height: 36px;
  background: rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  color: #333;
  cursor: pointer;
  z-index: 10;
  backdrop-filter: blur(4px);
  transition: transform 0.2s, background 0.2s;
}

.popup-close:hover {
  transform: scale(1.1);
  background: white;
}

.popup-timer {
  position: absolute;
  bottom: 12px;
  left: 50%;
  transform: translateX(-50%);
  padding: 6px 16px;
  background: rgba(0, 0, 0, 0.7);
  border-radius: 20px;
  color: white;
  font-size: 12px;
  backdrop-filter: blur(4px);
}

.fullscreen-popup {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.95);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1100;
}

.fullscreen-popup img {
  max-width: 100vw;
  max-height: 100vh;
  width: auto;
  height: auto;
  object-fit: contain;
}

/* 弹窗动画 */
.popup-fade-enter-active,
.popup-fade-leave-active {
  transition: opacity 0.3s ease;
}

.popup-fade-enter-from,
.popup-fade-leave-to {
  opacity: 0;
}

.popup-fade-enter-active .popup-container {
  animation: popupScaleIn 0.3s ease;
}

@keyframes popupScaleIn {
  0% {
    transform: scale(0.8);
    opacity: 0;
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}
</style>
