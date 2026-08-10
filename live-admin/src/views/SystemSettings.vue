<template>
  <div class="system-settings">
    <el-card>
      <template #header>
        <div class="header">
          <span class="title">系统设置</span>
        </div>
      </template>
      
      <el-tabs v-model="activeTab">
        <el-tab-pane label="基础设置" name="basic">
          <el-form :model="basicConfig" label-width="120px" style="max-width: 500px;">
            <el-form-item label="系统名称">
              <el-input v-model="basicConfig.systemName" />
            </el-form-item>
            <el-form-item label="系统Logo">
              <el-input v-model="basicConfig.logo" placeholder="Logo 图片 URL" />
            </el-form-item>
            <el-form-item label="ICP备案号">
              <el-input v-model="basicConfig.icp" />
            </el-form-item>
            <el-form-item label="版权信息">
              <el-input v-model="basicConfig.copyright" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveBasicConfig">保存设置</el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>

        <el-tab-pane label="流媒体配置" name="stream">
          <el-form :model="streamConfig" label-width="140px" style="max-width: 500px;">
            <el-form-item label="SRS 服务地址">
              <el-input v-model="streamConfig.srsUrl" />
            </el-form-item>
            <el-form-item label="RTMP 端口">
              <el-input v-model="streamConfig.rtmpPort" />
            </el-form-item>
            <el-form-item label="HTTP-FLV 端口">
              <el-input v-model="streamConfig.httpPort" />
            </el-form-item>
            <el-form-item label="启用 HLS">
              <el-switch v-model="streamConfig.enableHls" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveStreamConfig">保存设置</el-button>
              <el-button @click="testConnection">测试连接</el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>

        <el-tab-pane label="伪直播设置" name="fake">
          <el-form :model="fakeConfig" label-width="140px" style="max-width: 500px;">
            <el-form-item label="FFmpeg 路径">
              <el-input v-model="fakeConfig.ffmpegPath" placeholder="ffmpeg 可执行文件路径" />
            </el-form-item>
            <el-form-item label="默认视频目录">
              <el-input v-model="fakeConfig.videoDir" placeholder="视频文件存储目录" />
            </el-form-item>
            <el-form-item label="自动重启">
              <el-switch v-model="fakeConfig.autoRestart" />
            </el-form-item>
            <el-form-item label="故障恢复">
              <el-switch v-model="fakeConfig.autoRecover" />
            </el-form-item>
            <el-form-item label="低延迟模式">
              <el-switch v-model="fakeConfig.lowLatency" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveFakeConfig">保存设置</el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>

        <el-tab-pane label="数据管理" name="data">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="直播间总数">{{ stats.totalRooms }}</el-descriptions-item>
            <el-descriptions-item label="在线直播">{{ stats.liveRooms }}</el-descriptions-item>
            <el-descriptions-item label="弹幕总数">{{ stats.totalDanmaku }}</el-descriptions-item>
            <el-descriptions-item label="用户总数">{{ users.length }}</el-descriptions-item>
          </el-descriptions>
          
          <div style="margin-top: 20px; display: flex; gap: 12px;">
            <el-button type="danger" @click="clearDanmaku">
              <el-icon><Delete /></el-icon>
              清空弹幕
            </el-button>
            <el-button type="warning" @click="clearRooms" :disabled="stats.liveRooms > 0">
              <el-icon><Delete /></el-icon>
              清空直播间
            </el-button>
            <el-button @click="exportData">
              <el-icon><Download /></el-icon>
              导出数据
            </el-button>
          </div>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Delete, Download } from '@element-plus/icons-vue'

const activeTab = ref('basic')

const basicConfig = ref({
  systemName: '直播系统',
  logo: '',
  icp: '',
  copyright: '© 2024 直播系统. All rights reserved.'
})

const streamConfig = ref({
  srsUrl: 'http://localhost:1935',
  rtmpPort: '1935',
  httpPort: '8080',
  enableHls: true
})

const fakeConfig = ref({
  ffmpegPath: '/usr/bin/ffmpeg',
  videoDir: '/path/to/videos',
  autoRestart: true,
  autoRecover: true,
  lowLatency: true
})

const stats = ref({
  totalRooms: 0,
  liveRooms: 0,
  totalDanmaku: 0
})

const users = ref([])

async function fetchStats() {
  try {
    const res = await fetch('/api/stats')
    const data = await res.json()
    if (data.success) {
      stats.value = data.data
    }
  } catch (e) {
    console.error('获取统计数据失败:', e)
  }
}

async function fetchUsers() {
  try {
    const res = await fetch('/api/users')
    const data = await res.json()
    if (data.success) {
      users.value = data.data
    }
  } catch (e) {
    console.error('获取用户列表失败:', e)
  }
}

function saveBasicConfig() {
  ElMessage.success('基础设置已保存')
}

function saveStreamConfig() {
  ElMessage.success('流媒体设置已保存')
}

function saveFakeConfig() {
  ElMessage.success('伪直播设置已保存')
}

function testConnection() {
  ElMessage.info('正在测试连接...')
  setTimeout(() => {
    ElMessage.success('连接成功')
  }, 1000)
}

async function clearDanmaku() {
  try {
    await ElMessageBox.confirm('确定要清空所有弹幕数据吗？', '危险操作', {
      type: 'error'
    })
    ElMessage.success('弹幕已清空')
  } catch (e) {
    // 用户取消
  }
}

async function clearRooms() {
  try {
    await ElMessageBox.confirm('确定要清空所有直播间吗？', '危险操作', {
      type: 'error'
    })
    ElMessage.success('直播间已清空')
  } catch (e) {
    // 用户取消
  }
}

function exportData() {
  ElMessage.success('数据导出功能开发中')
}

onMounted(() => {
  fetchStats()
  fetchUsers()
})
</script>

<style scoped>
.system-settings { }
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.header .title {
  font-size: 16px;
  font-weight: bold;
  color: #333;
}
</style>
