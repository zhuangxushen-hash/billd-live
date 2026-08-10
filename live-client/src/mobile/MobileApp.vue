<template>
  <div class="mobile-app">
    <!-- 顶部导航栏 -->
    <header class="mobile-header">
      <div class="header-left" @click="currentView === 'player' && $emit('back')">
        <span v-if="currentView === 'player'" class="back-icon">‹</span>
        <span class="logo-text">{{ currentView === 'player' ? '返回' : '直播' }}</span>
      </div>
      <div class="header-right">
        <span class="user-name">{{ userName }}</span>
      </div>
    </header>

    <!-- 主内容区 -->
    <main class="mobile-main">
      <MobileRoomList 
        v-if="currentView === 'list'" 
        @enter-room="enterRoom"
      />
      <MobileRoomPlayer 
        v-else 
        :room-id="currentRoomId" 
        :user-name="userName"
        @back="currentView = 'list'"
      />
    </main>

    <!-- 登录弹窗 -->
    <div v-if="showLogin" class="login-modal" @click.self="showLogin = false">
      <div class="login-box">
        <h3>登录</h3>
        <input v-model="loginForm.username" placeholder="用户名" />
        <input v-model="loginForm.password" type="password" placeholder="密码" />
        <button class="login-submit" @click="doLogin">登录</button>
        <p class="login-tip">默认账号: admin / 123456</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import MobileRoomList from './MobileRoomList.vue'
import MobileRoomPlayer from './MobileRoomPlayer.vue'

const emit = defineEmits(['back'])

const currentView = ref('list')
const currentRoomId = ref(null)
const userName = ref('访客用户')
const showLogin = ref(false)
const loginForm = ref({ username: '', password: '' })

onMounted(() => {
  const saved = localStorage.getItem('userInfo')
  if (saved) {
    userName.value = JSON.parse(saved).nickname || '访客用户'
  }
})

function enterRoom(roomId) {
  currentRoomId.value = roomId
  currentView.value = 'player'
  window.scrollTo(0, 0)
}

async function doLogin() {
  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginForm.value)
    })
    const data = await res.json()
    if (data.success) {
      userName.value = data.data.nickname
      localStorage.setItem('userInfo', JSON.stringify(data.data))
      showLogin.value = false
    } else {
      alert(data.message)
    }
  } catch (e) {
    alert('登录失败')
  }
}
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
  
  --stitch-tertiary: #705d00;
  --stitch-tertiary-container: #c9a900;
  --stitch-tertiary-fixed: #ffe16d;
  
  --stitch-background: #f8f9fc;
  --stitch-surface: #f8f9fc;
  --stitch-surface-container: #edeef1;
  --stitch-surface-container-low: #f2f3f6;
  --stitch-surface-container-high: #e7e8eb;
  --stitch-surface-container-highest: #e1e2e5;
  --stitch-surface-variant: #e1e2e5;
  --stitch-on-surface: #191c1e;
  --stitch-on-surface-variant: #444653;
  --stitch-outline: #757684;
  --stitch-outline-variant: #c5c5d5;
  
  --stitch-gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  --stitch-gradient-text: linear-gradient(to right, #667eea, #764ba2);
  --stitch-gradient-header: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%);
  
  --stitch-radius-sm: 4px;
  --stitch-radius-md: 8px;
  --stitch-radius-lg: 12px;
  --stitch-radius-xl: 16px;
  --stitch-radius-full: 9999px;
  
  --stitch-safe-top: env(safe-area-inset-top, 0px);
  --stitch-safe-bottom: env(safe-area-inset-bottom, 0px);
}

.mobile-app {
  min-height: 100vh;
  background: var(--stitch-background);
  display: flex;
  flex-direction: column;
}

/* ============================================
   顶部导航栏 - Stitch毛玻璃风格
   ============================================ */
.mobile-header {
  position: sticky;
  top: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  height: 54px;
  background: var(--stitch-gradient-header);
  background-size: 200% 200%;
  animation: stitchHeaderGradient 10s ease infinite;
  color: white;
  box-shadow: 0 4px 20px rgba(102, 126, 234, 0.3);
  padding-top: var(--stitch-safe-top);
}

@keyframes stitchHeaderGradient {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

.header-left {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  transition: opacity 0.2s ease;
}

.header-left:active {
  opacity: 0.7;
}

.back-icon {
  font-size: 28px;
  font-weight: bold;
  line-height: 1;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border-radius: 50%;
  transition: all 0.3s ease;
}

.logo-text {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.5px;
}

/* Logo渐变文字效果 */
.logo-text {
  background: linear-gradient(to right, #fff, #ffe16d);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.user-name {
  font-size: 13px;
  opacity: 0.95;
  font-weight: 500;
  padding: 4px 12px;
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border-radius: var(--stitch-radius-full);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.mobile-main {
  flex: 1;
  padding-bottom: var(--stitch-safe-bottom);
}

/* ============================================
   登录弹窗 - 毛玻璃 + Stitch样式
   ============================================ */
.login-modal {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  animation: stitchFadeIn 0.3s ease;
}

@keyframes stitchFadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.login-box {
  background: white;
  padding: 28px 24px;
  border-radius: 20px;
  width: 300px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
  animation: stitchSlideUp 0.3s ease;
}

@keyframes stitchSlideUp {
  from { transform: translateY(20px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

.login-box h3 {
  text-align: center;
  color: var(--stitch-on-surface);
  margin-bottom: 8px;
  font-size: 18px;
  font-weight: 700;
}

.login-box input {
  padding: 12px 14px;
  border: 1.5px solid var(--stitch-outline-variant);
  border-radius: var(--stitch-radius-lg);
  font-size: 14px;
  transition: all 0.3s ease;
  background: var(--stitch-surface-container-low);
  color: var(--stitch-on-surface);
}

.login-box input:focus {
  border-color: var(--stitch-primary);
  background: white;
  outline: none;
  box-shadow: 0 0 0 3px rgba(57, 83, 189, 0.15);
}

.login-submit {
  padding: 12px;
  background: var(--stitch-gradient-primary);
  color: white;
  border: none;
  border-radius: var(--stitch-radius-lg);
  cursor: pointer;
  font-size: 15px;
  font-weight: 700;
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.4);
  transition: all 0.3s ease;
}

.login-submit:active {
  transform: scale(0.98);
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.login-tip {
  text-align: center;
  color: var(--stitch-outline-variant);
  font-size: 12px;
  margin-top: 4px;
}
</style>
