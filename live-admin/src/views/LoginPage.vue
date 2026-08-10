<template>
  <div class="login-page">
    <div class="login-container">
      <div class="login-header">
        <el-icon :size="40" color="#89b4fa"><VideoCamera /></el-icon>
        <h1>直播系统管理后台</h1>
        <p>欢迎回来，请登录继续</p>
      </div>
      
      <el-form :model="form" @submit.prevent="handleLogin" class="login-form">
        <el-form-item>
          <el-input
            v-model="form.username"
            placeholder="用户名"
            size="large"
            :prefix-icon="User"
          />
        </el-form-item>
        
        <el-form-item>
          <el-input
            v-model="form.password"
            type="password"
            placeholder="密码"
            size="large"
            :prefix-icon="Lock"
            show-password
          />
        </el-form-item>
        
        <el-button
          type="primary"
          size="large"
          :loading="loading"
          @click="handleLogin"
          class="login-btn"
        >
          登录
        </el-button>
        
        <p class="tip">默认账号: admin / 123456</p>
      </el-form>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'

const emit = defineEmits(['login-success'])

const form = ref({
  username: 'admin',
  password: '123456'
})
const loading = ref(false)

async function handleLogin() {
  loading.value = true
  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form.value)
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('登录成功')
      emit('login-success', data.data)
    } else {
      ElMessage.error(data.message || '登录失败')
    }
  } catch (e) {
    ElMessage.error('网络错误')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1e1e2e 0%, #313244 100%);
}
.login-container {
  background: white;
  padding: 40px;
  border-radius: 16px;
  width: 400px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}
.login-header {
  text-align: center;
  margin-bottom: 32px;
}
.login-header h1 {
  font-size: 20px;
  color: #333;
  margin: 12px 0 8px;
}
.login-header p {
  color: #999;
  font-size: 14px;
}
.login-form .el-input {
  margin-bottom: 8px;
}
.login-btn {
  width: 100%;
  margin-top: 16px;
  background: linear-gradient(135deg, #89b4fa 0%, #b4befe 100%);
  border: none;
}
.login-btn:hover {
  background: linear-gradient(135deg, #74c7ec 0%, #a6c8ff 100%) !important;
}
.tip {
  text-align: center;
  color: #999;
  font-size: 12px;
  margin-top: 16px;
}
</style>
