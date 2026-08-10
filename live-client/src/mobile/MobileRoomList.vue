<template>
  <div class="mobile-room-list">
    <!-- 轮播Banner -->
    <div class="banner" v-if="rooms.length > 0">
      <div class="banner-item">
        <span class="banner-icon">📺</span>
        <span class="banner-text">欢迎来到直播平台</span>
      </div>
    </div>

    <!-- 分类Tab -->
    <div class="category-tabs">
      <div 
        v-for="cat in categories" 
        :key="cat"
        class="tab-item"
        :class="{ active: selectedCategory === cat }"
        @click="selectedCategory = cat"
      >
        {{ cat === '' ? '全部' : cat }}
      </div>
    </div>

    <!-- 直播间列表 -->
    <div v-if="filteredRooms.length === 0" class="empty">
      <div class="empty-icon">📡</div>
      <p>暂无直播</p>
      <p class="empty-tip">主播还没有开播哦</p>
    </div>

    <div v-else class="room-list">
      <div 
        v-for="room in filteredRooms" 
        :key="room.id" 
        class="room-item"
        @click="$emit('enter-room', room.id)"
      >
        <!-- 封面图 -->
        <div class="room-cover">
          <img v-if="room.cover" :src="room.cover" :alt="room.title" />
          <div v-else class="cover-placeholder">{{ room.title.charAt(0) }}</div>
          
          <!-- 直播标签 -->
          <div class="live-tag" v-if="room.isLive">
            <span class="live-dot"></span>
            <span>LIVE</span>
          </div>
          
          <!-- 观众数 -->
          <div class="viewers" v-if="room.isLive">
            <span class="eye-icon">👁</span>
            <span>{{ formatCount(room.viewerCount || 0) }}</span>
          </div>
        </div>

        <!-- 信息区 -->
        <div class="room-info">
          <div class="room-title">{{ room.title }}</div>
          <div class="room-meta">
            <span class="category-tag">{{ room.category }}</span>
            <span class="status" :class="{ online: room.isLive }">
              {{ room.isLive ? '直播中' : '未开播' }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 下拉刷新提示 -->
    <div class="refresh-tip" v-if="rooms.length > 0">
      <span>下拉刷新</span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const emit = defineEmits(['enter-room'])

const categories = ['', '游戏', '娱乐', '教育', '其他']
const rooms = ref([])
const selectedCategory = ref('')
let timer = null

const filteredRooms = computed(() => {
  if (!selectedCategory.value) return rooms.value
  return rooms.value.filter(r => r.category === selectedCategory.value)
})

function formatCount(count) {
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + 'w'
  } else if (count >= 1000) {
    return (count / 1000).toFixed(1) + 'k'
  }
  return count
}

async function fetchRooms() {
  try {
    const res = await fetch('/api/rooms')
    const data = await res.json()
    if (data.success) {
      rooms.value = data.data
    }
  } catch (e) {
    console.error('获取直播间列表失败:', e)
  }
}

onMounted(() => {
  fetchRooms()
  timer = setInterval(fetchRooms, 5000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
/* ============================================
   Stitch 设计系统 - CSS 变量
   注意：scoped样式中不能使用 :root，变量需定义在组件根选择器上
   ============================================ */
.mobile-room-list {
  /* 颜色系统 */
  --stitch-primary: #3953bd;
  --stitch-primary-container: #546cd7;
  --stitch-primary-fixed: #dde1ff;
  --stitch-primary-fixed-dim: #b9c3ff;
  --stitch-on-primary: #ffffff;
  --stitch-on-primary-container: #fffbff;
  
  --stitch-secondary: #b9082c;
  --stitch-secondary-container: #dd2d42;
  --stitch-secondary-fixed: #ffdad9;
  --stitch-secondary-fixed-dim: #ffb3b2;
  --stitch-on-secondary: #ffffff;
  --stitch-on-secondary-container: #fffbff;
  --stitch-on-secondary-fixed: #410008;
  --stitch-on-secondary-fixed-variant: #920020;
  
  --stitch-tertiary: #705d00;
  --stitch-tertiary-container: #c9a900;
  --stitch-tertiary-fixed: #ffe16d;
  --stitch-tertiary-fixed-dim: #e9c400;
  --stitch-on-tertiary: #ffffff;
  --stitch-on-tertiary-container: #4c3f00;
  --stitch-on-tertiary-fixed: #221b00;
  --stitch-on-tertiary-fixed-variant: #544600;
  
  --stitch-background: #f8f9fc;
  --stitch-on-background: #191c1e;
  --stitch-surface: #f8f9fc;
  --stitch-surface-dim: #d9dadd;
  --stitch-surface-bright: #f8f9fc;
  --stitch-surface-container-lowest: #ffffff;
  --stitch-surface-container-low: #f2f3f6;
  --stitch-surface-container: #edeef1;
  --stitch-surface-container-high: #e7e8eb;
  --stitch-surface-container-highest: #e1e2e5;
  --stitch-surface-variant: #e1e2e5;
  --stitch-surface-tint: #3c55bf;
  --stitch-on-surface: #191c1e;
  --stitch-on-surface-variant: #444653;
  
  --stitch-outline: #757684;
  --stitch-outline-variant: #c5c5d5;
  
  --stitch-error: #ba1a1a;
  --stitch-error-container: #ffdad6;
  --stitch-on-error: #ffffff;
  --stitch-on-error-container: #93000a;
  
  --stitch-inverse-surface: #2e3133;
  --stitch-inverse-on-surface: #f0f1f4;
  --stitch-inverse-primary: #b9c3ff;
  
  /* 渐变系统 */
  --stitch-gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  --stitch-gradient-text: linear-gradient(to right, #667eea, #764ba2);
  --stitch-gradient-banner: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%);
  
  /* 间距系统 */
  --stitch-space-xs: 4px;
  --stitch-space-sm: 8px;
  --stitch-space-md: 16px;
  --stitch-space-lg: 24px;
  --stitch-space-xl: 32px;
  --stitch-space-gutter: 12px;
  --stitch-space-container: 16px;
  
  /* 圆角系统 */
  --stitch-radius-sm: 4px;
  --stitch-radius-md: 8px;
  --stitch-radius-lg: 12px;
  --stitch-radius-xl: 16px;
  --stitch-radius-full: 9999px;
  
  /* 阴影系统 */
  --stitch-shadow-card: 0 8px 24px rgba(0, 0, 0, 0.05);
  --stitch-shadow-sm: 0 2px 8px rgba(0, 0, 0, 0.04);
  --stitch-shadow-gradient: 0 4px 20px rgba(102, 126, 234, 0.3);
  
  /* 毛玻璃 */
  --stitch-glass-bg: rgba(25, 28, 30, 0.4);
  --stitch-glass-blur: blur(20px);
  --stitch-glass-border: 1px solid rgba(255, 255, 255, 0.2);
  
  /* 安全区域 */
  --stitch-safe-top: env(safe-area-inset-top, 0px);
  --stitch-safe-bottom: env(safe-area-inset-bottom, 0px);
  
  /* 基础样式 */
  padding-bottom: 20px;
  background: var(--stitch-background);
  min-height: calc(100vh - 50px);
}

/* Hero Banner */
.banner {
  margin: var(--stitch-space-container);
  border-radius: var(--stitch-radius-xl);
  overflow: hidden;
  box-shadow: var(--stitch-shadow-gradient);
}

.banner-item {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 18px 20px;
  background: var(--stitch-gradient-banner);
  background-size: 200% 200%;
  animation: stitchGradientShift 8s ease infinite;
  color: white;
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.5px;
}

@keyframes stitchGradientShift {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

.banner-icon {
  font-size: 28px;
  animation: stitchBounce 2s infinite;
}

@keyframes stitchBounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-3px); }
}

/* 分类Tab - 毛玻璃风格 */
.category-tabs {
  display: flex;
  gap: var(--stitch-space-gutter);
  padding: 4px var(--stitch-space-container) 16px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}

.category-tabs::-webkit-scrollbar {
  display: none;
}

.tab-item {
  flex-shrink: 0;
  padding: 8px 18px;
  background: var(--stitch-surface-container);
  border-radius: var(--stitch-radius-full);
  font-size: 13px;
  color: var(--stitch-on-surface-variant);
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  font-weight: 500;
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.tab-item:active {
  transform: scale(0.95);
}

.tab-item.active {
  background: var(--stitch-gradient-primary);
  color: white;
  font-weight: 700;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
  border-color: transparent;
}

/* 空状态 */
.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 80px 20px;
  color: var(--stitch-outline);
}

.empty-icon {
  font-size: 64px;
  margin-bottom: 20px;
  opacity: 0.6;
}

.empty p {
  font-size: 16px;
  color: var(--stitch-on-surface-variant);
  font-weight: 500;
}

.empty-tip {
  font-size: 13px;
  margin-top: 8px;
  color: var(--stitch-outline-variant);
}

/* 直播间网格 - 2列布局 */
.room-list {
  padding: 0 var(--stitch-space-container);
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--stitch-space-gutter);
}

/* 卡片样式 */
.room-item {
  background: var(--stitch-surface-container-lowest);
  border-radius: var(--stitch-radius-xl);
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: var(--stitch-shadow-card);
}

.room-item:active {
  transform: scale(0.96);
}

/* 封面区 */
.room-cover {
  position: relative;
  width: 100%;
  padding-top: 75%;
  background: var(--stitch-surface-variant);
  overflow: hidden;
}

.room-cover img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s ease;
}

.room-item:active .room-cover img {
  transform: scale(1.05);
}

.cover-placeholder {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
  color: white;
  font-weight: bold;
  background: var(--stitch-gradient-primary);
}

/* LIVE标签 - Stitch脉冲动画 */
.live-tag {
  position: absolute;
  top: 8px;
  left: 8px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  color: white;
  border-radius: var(--stitch-radius-full);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.live-dot {
  position: relative;
  width: 8px;
  height: 8px;
  background-color: #ff4757;
  border-radius: 50%;
  flex-shrink: 0;
}

.live-dot::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 100%;
  height: 100%;
  background-color: #ff4757;
  border-radius: 50%;
  transform: translate(-50%, -50%);
  animation: stitchPulseRing 1.5s cubic-bezier(0.215, 0.61, 0.355, 1) infinite;
}

@keyframes stitchPulseRing {
  0% {
    transform: translate(-50%, -50%) scale(1);
    opacity: 0.8;
  }
  100% {
    transform: translate(-50%, -50%) scale(3);
    opacity: 0;
  }
}

/* 观众数 - 毛玻璃 */
.viewers {
  position: absolute;
  top: 8px;
  right: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  color: white;
  border-radius: var(--stitch-radius-full);
  font-size: 11px;
  font-weight: 700;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.eye-icon {
  font-size: 12px;
}

/* 信息区 */
.room-info {
  padding: var(--stitch-space-md);
}

.room-title {
  font-size: 14px;
  color: var(--stitch-on-surface);
  margin-bottom: 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}

.room-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 11px;
}

.category-tag {
  padding: 3px 10px;
  background: var(--stitch-surface-container);
  border-radius: var(--stitch-radius-sm);
  color: var(--stitch-primary);
  font-weight: 700;
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
}

.status {
  color: var(--stitch-outline);
  font-weight: 500;
}

.status.online {
  color: #4ade80;
  display: flex;
  align-items: center;
  gap: 3px;
}

.status.online::before {
  content: '';
  width: 5px;
  height: 5px;
  background: #4ade80;
  border-radius: 50%;
}

/* 下拉刷新提示 */
.refresh-tip {
  text-align: center;
  padding: 24px;
  font-size: 12px;
  color: var(--stitch-outline-variant);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.refresh-tip::before {
  content: '↓';
  font-size: 14px;
}
</style>
