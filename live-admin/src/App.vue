<template>
  <el-container v-if="isLoggedIn" class="admin-layout">
    <el-aside width="220px" class="admin-aside">
      <div class="logo">
        <el-icon :size="24"><VideoCamera /></el-icon>
        <span>直播管理后台</span>
      </div>
      <el-menu
        :default-active="activeMenu"
        @select="handleMenuSelect"
        background-color="#1e1e2e"
        text-color="#cdd6f4"
        active-text-color="#89b4fa"
      >
        <el-menu-item index="dashboard">
          <el-icon><Odometer /></el-icon>
          <span>数据概览</span>
        </el-menu-item>
        <el-menu-item index="rooms">
          <el-icon><Monitor /></el-icon>
          <span>直播间管理</span>
        </el-menu-item>
        <el-menu-item index="stream">
          <el-icon><Promotion /></el-icon>
          <span>伪直播配置</span>
        </el-menu-item>
        <el-menu-item index="users">
          <el-icon><User /></el-icon>
          <span>用户管理</span>
        </el-menu-item>
        <el-menu-item index="settings">
          <el-icon><Setting /></el-icon>
          <span>系统设置</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="admin-header">
        <div class="header-left">
          <h2>{{ currentPageTitle }}</h2>
        </div>
        <div class="header-right">
          <el-dropdown @command="handleCommand">
            <span class="user-info">
              <el-icon><UserFilled /></el-icon>
              <span>{{ currentUser.nickname || '管理员' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile">个人资料</el-dropdown-item>
                <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-main class="admin-main">
        <Dashboard v-if="activeMenu === 'dashboard'" />
        <RoomManagement v-else-if="activeMenu === 'rooms'" />
        <StreamConfig v-else-if="activeMenu === 'stream'" />
        <UserManagement v-else-if="activeMenu === 'users'" />
        <SystemSettings v-else-if="activeMenu === 'settings'" />
      </el-main>
    </el-container>
  </el-container>

  <LoginPage v-else @login-success="handleLoginSuccess" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import Dashboard from './views/Dashboard.vue'
import RoomManagement from './views/RoomManagement.vue'
import StreamConfig from './views/StreamConfig.vue'
import UserManagement from './views/UserManagement.vue'
import SystemSettings from './views/SystemSettings.vue'
import LoginPage from './views/LoginPage.vue'

const activeMenu = ref('dashboard')
const isLoggedIn = ref(false)
const currentUser = ref({})

const menuTitles = {
  dashboard: '数据概览',
  rooms: '直播间管理',
  stream: '伪直播配置',
  users: '用户管理',
  settings: '系统设置'
}

const currentPageTitle = computed(() => menuTitles[activeMenu.value])

onMounted(() => {
  const saved = localStorage.getItem('adminUser')
  if (saved) {
    currentUser.value = JSON.parse(saved)
    isLoggedIn.value = true
  }
})

function handleMenuSelect(index) {
  activeMenu.value = index
}

function handleLoginSuccess(user) {
  currentUser.value = user
  localStorage.setItem('adminUser', JSON.stringify(user))
  isLoggedIn.value = true
}

function handleCommand(command) {
  if (command === 'logout') {
    localStorage.removeItem('adminUser')
    isLoggedIn.value = false
    ElMessage.success('已退出登录')
  }
}
</script>

<style scoped>
.admin-layout { height: 100vh; }
.admin-aside {
  background: #1e1e2e;
  color: white;
  display: flex;
  flex-direction: column;
}
.logo {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 20px;
  font-size: 18px;
  font-weight: bold;
  color: #89b4fa;
  border-bottom: 1px solid #313244;
}
.admin-aside .el-menu {
  border-right: none;
  flex: 1;
}
.admin-header {
  background: white;
  border-bottom: 1px solid #e0e0e0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 24px;
}
.header-left h2 {
  font-size: 18px;
  color: #333;
}
.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 8px 12px;
  border-radius: 8px;
  transition: background 0.2s;
}
.user-info:hover {
  background: #f5f5f5;
}
.admin-main {
  background: #f5f5f5;
  padding: 20px;
  overflow-y: auto;
}
</style>
