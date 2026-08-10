<template>
  <!-- 移动端视图 -->
  <MobileApp v-if="isMobile" @back="currentView = 'list'" />
  
  <!-- PC端视图 -->
  <div v-else class="app">
    <header class="header">
      <div class="logo" @click="currentView = 'list'">
        <span class="logo-icon">📺</span>
        <span class="logo-text">直播平台</span>
      </div>
      <nav class="nav">
        <span 
          class="nav-item" 
          :class="{ active: currentView === 'list' }"
          @click="currentView = 'list'"
        >
          直播间
        </span>
      </nav>
      <div class="user-info">
        <span class="user-name">{{ userName }}</span>
        <button class="login-btn" @click="showLogin = true">登录</button>
        <!-- 切换到移动端预览 -->
        <button class="mobile-btn" @click="previewMobile = true">移动端预览</button>
      </div>
    </header>

    <main class="main">
      <RoomList 
        v-if="currentView === 'list'" 
        @enter-room="enterRoom"
      />
      <RoomPlayer 
        v-else 
        :room-id="currentRoomId" 
        :user-name="userName"
        @back="currentView = 'list'"
      />
    </main>

    <div v-if="showLogin" class="login-modal" @click.self="showLogin = false">
      <div class="login-box">
        <h3>登录</h3>
        <input v-model="loginForm.username" placeholder="用户名" />
        <input v-model="loginForm.password" type="password" placeholder="密码" />
        <button class="login-submit" @click="doLogin">登录</button>
        <p class="login-tip">默认账号: admin / 123456</p>
      </div>
    </div>

    <!-- 移动端预览弹窗 -->
    <div v-if="previewMobile" class="mobile-preview-modal" @click.self="previewMobile = false">
      <div class="preview-container">
        <div class="preview-header">
          <span>移动端预览</span>
          <span class="close-btn" @click="previewMobile = false">×</span>
        </div>
        <div class="phone-frame">
          <MobileApp />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import MobileApp from './mobile/MobileApp.vue'
import RoomList from './views/RoomList.vue'
import RoomPlayer from './views/RoomPlayer.vue'

const currentView = ref('list')
const currentRoomId = ref(null)
const userName = ref('访客用户')
const showLogin = ref(false)
const loginForm = ref({ username: '', password: '' })
const previewMobile = ref(false)

// 移动端检测
const isMobile = ref(false)
let resizeTimer = null
let forceDevice = null

function checkDevice() {
  // 检查URL参数是否强制指定了设备类型
  const params = new URLSearchParams(window.location.search)
  const deviceParam = params.get('device')
  
  if (deviceParam === 'pc') {
    // 显式指定PC端
    isMobile.value = false
    forceDevice = 'pc'
    return
  } else if (deviceParam === 'mobile') {
    // 显式指定移动端
    isMobile.value = true
    forceDevice = 'mobile'
    return
  }
  
  // 默认移动端优先（适配微信H5场景）
  // 移动设备UA直接返回移动端
  const userAgent = navigator.userAgent.toLowerCase()
  const mobileKeywords = ['android', 'iphone', 'ipad', 'mobile', 'windows phone', 'micromessenger']
  const isMobileUA = mobileKeywords.some(keyword => userAgent.includes(keyword))
  
  // 移动端设备或小屏幕默认显示移动端视图
  if (isMobileUA) {
    isMobile.value = true
  } else {
    // PC端默认也显示移动端视图以适配H5展示需求
    // 可通过 ?device=pc 切换到PC视图
    isMobile.value = true
  }
}

onMounted(() => {
  // 初始检测
  checkDevice()
  
  // 窗口大小变化时重新检测（仅在没有强制指定设备模式时）
  window.addEventListener('resize', () => {
    if (resizeTimer) clearTimeout(resizeTimer)
    resizeTimer = setTimeout(() => {
      if (!forceDevice) {
        checkDevice()
      }
    }, 300)
  })
  
  const saved = localStorage.getItem('userInfo')
  if (saved) {
    userName.value = JSON.parse(saved).nickname || '访客用户'
  }
})

onUnmounted(() => {
  window.removeEventListener('resize', checkDevice)
})

function enterRoom(roomId) {
  currentRoomId.value = roomId
  currentView.value = 'player'
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
.app { min-height: 100vh; background: #f5f5f5; }
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  height: 60px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.logo { cursor: pointer; display: flex; align-items: center; gap: 8px; }
.logo-icon { font-size: 24px; }
.logo-text { font-size: 18px; font-weight: bold; }
.nav { display: flex; gap: 20px; }
.nav-item { 
  cursor: pointer; 
  padding: 8px 16px; 
  border-radius: 20px;
  transition: all 0.3s;
}
.nav-item.active { background: rgba(255,255,255,0.2); }
.user-info { display: flex; align-items: center; gap: 12px; }
.user-name { font-size: 14px; }
.login-btn {
  padding: 6px 16px;
  border: none;
  border-radius: 20px;
  background: white;
  color: #667eea;
  cursor: pointer;
  font-weight: bold;
}
.mobile-btn {
  padding: 6px 16px;
  border: 1px solid rgba(255,255,255,0.5);
  border-radius: 20px;
  background: transparent;
  color: white;
  cursor: pointer;
  font-size: 13px;
}
.main { padding: 20px; }
.login-modal {
  position: fixed; inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex; align-items: center; justify-content: center;
  z-index: 1000;
}
.login-box {
  background: white; padding: 30px;
  border-radius: 12px; width: 300px;
  display: flex; flex-direction: column; gap: 12px;
}
.login-box h3 { text-align: center; color: #333; }
.login-box input {
  padding: 10px 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 14px;
}
.login-submit {
  padding: 10px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white; border: none; border-radius: 8px;
  cursor: pointer; font-size: 16px; font-weight: bold;
}
.login-tip { text-align: center; color: #999; font-size: 12px; }

/* 移动端预览弹窗 */
.mobile-preview-modal {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
}

.preview-container {
  width: 375px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  background: #1a1a1a;
  border-radius: 24px;
  overflow: hidden;
}

.preview-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  color: white;
  font-size: 14px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
}

.close-btn {
  font-size: 24px;
  cursor: pointer;
  padding: 0 8px;
}

.phone-frame {
  height: 700px;
  overflow-y: auto;
  background: #f5f5f5;
}

/* 当屏幕较小时，预览弹窗自适应 */
@media (max-width: 420px) {
  .preview-container {
    width: 100%;
    height: 100%;
    max-height: 100vh;
    border-radius: 0;
  }
  
  .phone-frame {
    height: calc(100vh - 50px);
  }
}
</style>
