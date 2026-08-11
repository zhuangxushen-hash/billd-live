<template>
  <div class="stream-config">
    <el-card>
      <template #header>
        <div class="header">
          <span class="title">直播配置中心</span>
          <el-tag :type="currentLiveMode === 'fake' ? 'info' : 'success'">
            {{ currentLiveMode === 'fake' ? '伪直播模式' : '正常直播模式' }}
          </el-tag>
        </div>
      </template>
      
      <!-- 直播模式选择 -->
      <el-card class="mode-selector" style="margin-bottom: 20px;">
        <template #header>
          <span>直播模式</span>
        </template>
        <el-radio-group v-model="currentLiveMode" @change="onLiveModeChange">
          <el-radio value="normal">正常直播</el-radio>
          <el-radio value="fake">伪直播（视频循环）</el-radio>
        </el-radio-group>
        <div class="mode-description">
          <template v-if="currentLiveMode === 'normal'">
            <p><strong>正常直播：</strong>支持真实RTMP推流，主播使用OBS等推流软件进行直播，延迟低，互动性强</p>
          </template>
          <template v-else>
            <p><strong>伪直播：</strong>使用预录制视频循环播放模拟直播，支持24小时无人值守，适合直播带货、课程回放等场景</p>
          </template>
        </div>
      </el-card>
      
      <el-steps :active="currentStep" simple class="steps" v-if="currentLiveMode === 'fake'">
        <el-step title="选择直播间" />
        <el-step title="上传视频" />
        <el-step title="配置直播" />
        <el-step title="开始伪直播" />
      </el-steps>
      
      <el-steps :active="currentStep" simple class="steps" v-else>
        <el-step title="选择直播间" />
        <el-step title="配置推流" />
        <el-step title="开始直播" />
      </el-steps>

      <el-row :gutter="20" style="margin-top: 24px;">
        <el-col :span="12">
          <!-- 伪直播步骤 -->
          <template v-if="currentLiveMode === 'fake'">
          <!-- 步骤 1: 选择直播间 -->
          <el-card class="step-card" v-if="currentStep === 0">
            <h3>步骤 1: 选择要进行伪直播的直播间</h3>
            <el-form :model="selectedRoom" label-width="100px">
              <el-form-item label="直播间">
                <el-select v-model="selectedRoom.id" placeholder="请选择直播间" style="width: 100%;">
                  <el-option 
                    v-for="room in rooms" 
                    :key="room.id" 
                    :label="room.title" 
                    :value="room.id"
                  >
                    <span>{{ room.title }}</span>
                    <el-tag size="small" :type="room.isLive ? 'success' : 'info'" style="margin-left: 8px;">
                      {{ room.isLive ? '直播中' : '未开播' }}
                    </el-tag>
                  </el-option>
                </el-select>
              </el-form-item>
            </el-form>
            <el-button type="primary" @click="currentStep = 1" :disabled="!selectedRoom.id">
              下一步
            </el-button>
          </el-card>

          <!-- 步骤 2: 上传/选择视频 -->
          <el-card class="step-card" v-if="currentStep === 1">
            <h3>步骤 2: 准备视频文件</h3>
            
            <el-tabs v-model="videoTab">
              <el-tab-pane label="上传视频" name="upload">
                <el-upload
                  class="video-uploader"
                  drag
                  :auto-upload="false"
                  :on-change="handleFileChange"
                  :show-file-list="false"
                  accept=".mp4,.webm,.flv,.mkv,.mov"
                >
                  <el-icon class="el-icon--upload"><upload-filled /></el-icon>
                  <div class="el-upload__text">
                    将视频文件拖到此处，或<em>点击上传</em>
                  </div>
                  <template #tip>
                    <div class="el-upload__tip">
                      支持 MP4、WebM、FLV、MKV、MOV 格式，单个文件不超过 500MB
                    </div>
                  </template>
                </el-upload>
                <div v-if="uploading" class="upload-progress">
                  <el-progress :percentage="uploadProgress" />
                  <span>{{ uploadProgress }}%</span>
                </div>
              </el-tab-pane>
              
              <el-tab-pane label="选择已有视频" name="select">
                <div v-if="videos.length === 0" class="empty-videos">
                  <el-empty description="暂无视频，请先上传" />
                </div>
                <div v-else class="video-list">
                  <div 
                    v-for="video in videos" 
                    :key="video.filename" 
                    class="video-item"
                    :class="{ selected: videoConfig.path === video.filename }"
                    @click="selectVideo(video)"
                  >
                    <div class="video-thumbnail">
                      <el-icon :size="32"><film /></el-icon>
                    </div>
                    <div class="video-info">
                      <div class="video-name">{{ video.filename }}</div>
                      <div class="video-size">{{ formatSize(video.size) }}</div>
                    </div>
                    <el-button 
                      type="danger" 
                      size="small" 
                      @click.stop="deleteVideo(video.filename)"
                    >
                      删除
                    </el-button>
                  </div>
                </div>
              </el-tab-pane>
            </el-tabs>

            <el-form :model="videoConfig" label-width="120px" style="margin-top: 16px;">
              <el-form-item label="当前视频">
                <el-input 
                  :model-value="videoConfig.path || '未选择视频'" 
                  readonly 
                  placeholder="请上传或选择视频"
                />
              </el-form-item>
              <el-form-item label="循环次数">
                <el-select v-model="videoConfig.loopCount">
                  <el-option label="无限循环" :value="-1" />
                  <el-option label="1 次" :value="1" />
                  <el-option label="3 次" :value="3" />
                  <el-option label="5 次" :value="5" />
                  <el-option label="10 次" :value="10" />
                </el-select>
              </el-form-item>
            </el-form>
            
            <div class="btn-group">
              <el-button @click="currentStep = 0">上一步</el-button>
              <el-button type="primary" @click="currentStep = 2" :disabled="!videoConfig.path">下一步</el-button>
            </div>
          </el-card>

          <!-- 步骤 3: 配置直播 -->
          <el-card class="step-card" v-if="currentStep === 2">
            <h3>步骤 3: 配置伪直播参数</h3>
            <el-form :model="streamConfig" label-width="120px">
              <el-form-item label="直播模式">
                <el-radio-group v-model="streamConfig.mode">
                  <el-radio value="direct">直接播放（推荐）</el-radio>
                  <el-radio value="rtmp">RTMP 推流（需 SRS）</el-radio>
                </el-radio-group>
                <div class="mode-tip">
                  <template v-if="streamConfig.mode === 'direct'">
                    直接播放视频文件URL，无需额外服务，适合简单伪直播
                  </template>
                  <template v-else>
                    使用 FFmpeg 循环推流到 SRS 流媒体服务器，延迟更低
                  </template>
                </div>
              </el-form-item>
              <el-form-item v-if="streamConfig.mode === 'rtmp'" label="推流地址">
                <el-input v-model="streamConfig.url" readonly>
                  <template #append>
                    <el-button @click="copyToClipboard(streamConfig.url)">复制</el-button>
                  </template>
                </el-input>
              </el-form-item>
              <el-form-item v-if="streamConfig.mode === 'rtmp'" label="低延迟模式">
                <el-switch v-model="streamConfig.lowLatency" />
              </el-form-item>
              <el-form-item label="自动启动">
                <el-switch v-model="streamConfig.autoStart" />
                <span class="tip">配置完成后自动开始伪直播</span>
              </el-form-item>
            </el-form>
            <div class="btn-group">
              <el-button @click="currentStep = 1">上一步</el-button>
              <el-button type="primary" @click="currentStep = 3">下一步</el-button>
            </div>
          </el-card>

          <!-- 步骤 4: 开始伪直播 -->
          <el-card class="step-card" v-if="currentStep === 3">
            <h3>步骤 4: 确认并开始伪直播</h3>
            
            <el-descriptions :column="1" border>
              <el-descriptions-item label="直播间">
                {{ selectedRoomData?.title || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="视频文件">
                {{ videoConfig.path || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="循环次数">
                {{ videoConfig.loopCount === -1 ? '无限循环' : videoConfig.loopCount + ' 次' }}
              </el-descriptions-item>
              <el-descriptions-item label="直播模式">
                {{ streamConfig.mode === 'direct' ? '直接播放' : 'RTMP 推流' }}
              </el-descriptions-item>
              <el-descriptions-item v-if="streamConfig.mode === 'rtmp'" label="推流地址">
                <code>{{ streamConfig.url }}</code>
              </el-descriptions-item>
            </el-descriptions>

            <div class="command-preview" v-if="streamConfig.mode === 'rtmp'">
              <p class="label">FFmpeg 命令:</p>
              <pre class="command">{{ ffmpegCommand }}</pre>
            </div>

            <div class="btn-group">
              <el-button @click="currentStep = 2">上一步</el-button>
              <el-button 
                v-if="streamConfig.mode === 'rtmp'" 
                type="primary" 
                @click="copyToClipboard(ffmpegCommand)"
              >
                复制 FFmpeg 命令
              </el-button>
              <el-button 
                type="success" 
                @click="startFakeLive"
                :loading="starting"
              >
                <el-icon><VideoPlay /></el-icon>
                {{ isStreaming ? '停止伪直播' : '一键启动伪直播' }}
              </el-button>
            </div>
          </el-card>
          </template>
          
          <!-- 正常直播步骤 -->
          <template v-if="currentLiveMode === 'normal'">
            <!-- 步骤 1: 选择直播间 -->
            <el-card class="step-card" v-if="currentStep === 0">
              <h3>步骤 1: 选择直播间</h3>
              <el-form :model="selectedRoom" label-width="100px">
                <el-form-item label="直播间">
                  <el-select v-model="selectedRoom.id" placeholder="请选择直播间" style="width: 100%;">
                    <el-option 
                      v-for="room in rooms" 
                      :key="room.id" 
                      :label="room.title" 
                      :value="room.id"
                    >
                      <span>{{ room.title }}</span>
                      <el-tag size="small" :type="room.isLive ? 'success' : 'info'" style="margin-left: 8px;">
                        {{ room.isLive ? '直播中' : '未开播' }}
                      </el-tag>
                    </el-option>
                  </el-select>
                </el-form-item>
              </el-form>
              <el-button type="primary" @click="selectRoomForNormal" :disabled="!selectedRoom.id">
                下一步
              </el-button>
            </el-card>

            <!-- 步骤 2: 配置推流 -->
            <el-card class="step-card" v-if="currentStep === 1">
              <h3>步骤 2: 配置推流信息</h3>
              <el-descriptions :column="1" border>
                <el-descriptions-item label="直播间">
                  {{ selectedRoomData?.title || '-' }}
                </el-descriptions-item>
                <el-descriptions-item label="直播模式">
                  <el-tag type="success">正常直播</el-tag>
                </el-descriptions-item>
              </el-descriptions>
              
              <el-divider>推流地址配置</el-divider>
              
              <el-form label-width="120px">
                <el-form-item label="RTMP推流地址">
                  <el-input :model-value="normalStreamConfig.rtmpUrl" readonly>
                    <template #append>
                      <el-button @click="copyToClipboard(normalStreamConfig.rtmpUrl)">复制</el-button>
                    </template>
                  </el-input>
                  <div class="form-tip">使用OBS、推流助手等软件推流时使用此地址</div>
                </el-form-item>
                
                <el-form-item label="推流密钥">
                  <el-input :model-value="normalStreamConfig.streamKey" readonly type="password" show-password>
                    <template #append>
                      <el-button @click="copyToClipboard(normalStreamConfig.streamKey)">复制</el-button>
                    </template>
                  </el-input>
                  <div class="form-tip">请妥善保管推流密钥，不要泄露</div>
                </el-form-item>
                
                <el-form-item label="拉流地址 (FLV)">
                  <el-input :model-value="normalStreamConfig.flvUrl" readonly>
                    <template #append>
                      <el-button @click="copyToClipboard(normalStreamConfig.flvUrl)">复制</el-button>
                    </template>
                  </el-input>
                  <div class="form-tip">低延迟，适合PC端播放</div>
                </el-form-item>
                
                <el-form-item label="拉流地址 (HLS)">
                  <el-input :model-value="normalStreamConfig.hlsUrl" readonly>
                    <template #append>
                      <el-button @click="copyToClipboard(normalStreamConfig.hlsUrl)">复制</el-button>
                    </template>
                  </el-input>
                  <div class="form-tip">兼容性好，适合移动端播放</div>
                </el-form-item>
                
                <el-form-item label="密钥操作">
                  <el-button type="warning" @click="regenerateStreamKey">
                    <el-icon><Refresh /></el-icon>
                    重新生成密钥
                  </el-button>
                </el-form-item>
              </el-form>
              
              <div class="srs-status">
                <el-alert
                  v-if="!srsConfigured"
                  title="SRS流媒体服务器未配置"
                  type="warning"
                  description="正常直播需要SRS流媒体服务器支持，请在docker-compose.yml中配置SRS服务"
                  show-icon
                />
                <el-alert
                  v-else
                  title="SRS流媒体服务器已配置"
                  type="success"
                  :description="`服务器地址: ${srsConfig.host}:${srsConfig.rtmpPort}`"
                  show-icon
                />
              </div>
              
              <div class="btn-group">
                <el-button @click="currentStep = 0">上一步</el-button>
                <el-button type="primary" @click="currentStep = 2">下一步</el-button>
              </div>
            </el-card>

            <!-- 步骤 3: 开始直播 -->
            <el-card class="step-card" v-if="currentStep === 2">
              <h3>步骤 3: 开始正常直播</h3>
              
              <el-descriptions :column="1" border>
                <el-descriptions-item label="直播间">
                  {{ selectedRoomData?.title || '-' }}
                </el-descriptions-item>
                <el-descriptions-item label="直播模式">
                  <el-tag type="success">正常直播</el-tag>
                </el-descriptions-item>
                <el-descriptions-item label="推流地址">
                  <code>{{ normalStreamConfig.rtmpUrl }}</code>
                </el-descriptions-item>
              </el-descriptions>
              
              <el-divider>OBS 推流配置</el-divider>
              
              <div class="obs-config">
                <p><strong>在OBS中配置：</strong></p>
                <ol>
                  <li>打开OBS设置 → 推流</li>
                  <li>服务选择"自定义"</li>
                  <li>服务器：<code>rtmp://{{ srsConfig.host }}:{{ srsConfig.rtmpPort }}/live</code></li>
                  <li>串流密钥：<code>{{ normalStreamConfig.streamKey }}</code></li>
                  <li>点击"开始推流"</li>
                </ol>
              </div>

              <div class="btn-group">
                <el-button @click="currentStep = 1">上一步</el-button>
                <el-button 
                  type="success" 
                  @click="startNormalLive"
                  :loading="starting"
                >
                  <el-icon><VideoPlay /></el-icon>
                  {{ isStreaming ? '停止直播' : '一键开启直播' }}
                </el-button>
              </div>
            </el-card>
          </template>
        </el-col>

        <el-col :span="12">
          <!-- 直播预览 -->
          <el-card class="preview-card">
            <h3>{{ currentLiveMode === 'fake' ? '伪直播预览' : '直播状态监控' }}</h3>
            <div class="preview-area">
              <template v-if="isStreaming">
                <video 
                  v-if="currentLiveMode === 'fake'"
                  ref="previewVideo" 
                  :src="previewUrl"
                  autoplay 
                  muted
                  loop
                  class="preview-video"
                ></video>
                <div v-else class="normal-live-preview">
                  <el-icon :size="48" color="#67c23a"><VideoPlay /></el-icon>
                  <p class="live-status">直播进行中</p>
                  <p class="live-tip">请使用推流软件推流后查看画面</p>
                </div>
              </template>
              <div v-else class="preview-placeholder">
                <el-icon :size="64"><VideoCamera /></el-icon>
                <p>暂无直播画面</p>
                <p class="tip">{{ currentLiveMode === 'fake' ? '完成配置后点击"一键启动伪直播"' : '完成配置后点击"一键开启直播"' }}</p>
              </div>
            </div>
            <div class="stream-info" v-if="isStreaming">
              <el-tag type="success" effect="dark">直播中</el-tag>
              <span class="stream-time">{{ streamDuration }}</span>
            </div>
          </el-card>

          <!-- 直播说明 -->
          <el-card class="guide-card">
            <h3>{{ currentLiveMode === 'fake' ? '伪直播说明' : '正常直播说明' }}</h3>
            <el-descriptions v-if="currentLiveMode === 'fake'" :column="1" border>
              <el-descriptions-item label="原理">
                将预录制的视频文件作为直播源，循环播放模拟真实直播
              </el-descriptions-item>
              <el-descriptions-item label="优点">
                无需真人出镜，24 小时无人值守，资源占用极低
              </el-descriptions-item>
              <el-descriptions-item label="直接播放">
                直接提供视频文件URL，浏览器原生播放，配置简单
              </el-descriptions-item>
              <el-descriptions-item label="RTMP 推流">
                需要 SRS 流媒体服务器，延迟更低，支持更多播放协议
              </el-descriptions-item>
              <el-descriptions-item label="适用场景">
                直播带货、课程回放、游戏直播、电影轮播等
              </el-descriptions-item>
            </el-descriptions>
            <el-descriptions v-else :column="1" border>
              <el-descriptions-item label="原理">
                使用RTMP协议推流到SRS流媒体服务器，观众通过HTTP-FLV或HLS协议拉流观看
              </el-descriptions-item>
              <el-descriptions-item label="推流工具">
                OBS、推流助手、XSplit等支持RTMP推流的软件
              </el-descriptions-item>
              <el-descriptions-item label="播放协议">
                HTTP-FLV（低延迟）、HLS（高兼容）
              </el-descriptions-item>
              <el-descriptions-item label="优点">
                实时互动、支持多人连麦、观众延迟低
              </el-descriptions-item>
              <el-descriptions-item label="适用场景">
                游戏直播、娱乐直播、教育直播、企业会议等
              </el-descriptions-item>
            </el-descriptions>
          </el-card>
        </el-col>
      </el-row>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { VideoPlay, UploadFilled, Film, VideoCamera, Refresh } from '@element-plus/icons-vue'

const currentStep = ref(0)
const currentLiveMode = ref('normal') // normal: 正常直播, fake: 伪直播
const videoTab = ref('upload')
const rooms = ref([])
const videos = ref([])
const selectedRoom = ref({ id: null })
const videoConfig = ref({
  path: '',
  loopCount: -1
})
const streamConfig = ref({
  mode: 'direct',
  url: '',
  lowLatency: true,
  autoStart: true
})

// 正常直播配置
const normalStreamConfig = ref({
  rtmpUrl: '',
  flvUrl: '',
  hlsUrl: '',
  streamKey: ''
})
const srsConfig = ref({
  host: 'localhost',
  rtmpPort: 1935,
  httpPort: 8080
})
const srsConfigured = ref(true)

const isStreaming = ref(false)
const starting = ref(false)
const streamStartTime = ref(null)
const streamDuration = ref('00:00:00')
let durationTimer = null
let uploadTimer = null
const uploadProgress = ref(0)
const uploading = ref(false)

const selectedRoomData = computed(() => {
  return rooms.value.find(r => r.id === selectedRoom.value.id)
})

const previewUrl = computed(() => {
  if (!videoConfig.value.path) return ''
  return `/videos/${videoConfig.value.path}`
})

const ffmpegCommand = computed(() => {
  if (!selectedRoom.value.id || !streamConfig.value.url || !videoConfig.value.path) return ''
  
  const videoUrl = `${window.location.origin}/videos/${videoConfig.value.path}`
  const loopParam = videoConfig.value.loopCount === -1 ? '-1' : videoConfig.value.loopCount
  
  let command = `ffmpeg -re -stream_loop ${loopParam} -i "${videoUrl}"`
  
  command += ' -c copy'
  
  if (streamConfig.value.lowLatency) {
    command += ' -tune zerolatency'
  }
  
  command += ` -f flv "${streamConfig.value.url}"`
  
  return command
})

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

async function fetchVideos() {
  try {
    const res = await fetch('/api/videos')
    const data = await res.json()
    if (data.success) {
      videos.value = data.data
    }
  } catch (e) {
    console.error('获取视频列表失败:', e)
  }
}

async function fetchStreamUrl() {
  if (!selectedRoom.value.id) return
  try {
    const res = await fetch(`/api/rooms/${selectedRoom.value.id}/stream-url`)
    const data = await res.json()
    if (data.success) {
      streamConfig.value.url = data.data.rtmpUrl
    }
  } catch (e) {
    console.error('获取推流地址失败:', e)
  }
}

function handleFileChange(uploadFile) {
  const file = uploadFile.raw
  if (!file) return
  
  const allowedTypes = ['.mp4', '.webm', '.flv', '.mkv', '.mov']
  const ext = '.' + file.name.split('.').pop().toLowerCase()
  if (!allowedTypes.includes(ext)) {
    ElMessage.error('不支持的视频格式')
    return
  }
  
  uploading.value = true
  uploadProgress.value = 0
  
  const formData = new FormData()
  formData.append('video', file)
  
  const xhr = new XMLHttpRequest()
  
  xhr.upload.onprogress = (e) => {
    if (e.lengthComputable) {
      uploadProgress.value = Math.round((e.loaded / e.total) * 100)
    }
  }
  
  xhr.onload = async () => {
    uploading.value = false
    if (xhr.status === 200) {
      const result = JSON.parse(xhr.responseText)
      if (result.success) {
        videoConfig.value.path = result.data.filename
        ElMessage.success('视频上传成功')
        fetchVideos()
      } else {
        ElMessage.error(result.message || '上传失败')
      }
    } else {
      ElMessage.error('上传失败')
    }
  }
  
  xhr.onerror = () => {
    uploading.value = false
    ElMessage.error('上传失败')
  }
  
  xhr.open('POST', '/api/upload/video')
  xhr.send(formData)
}

function selectVideo(video) {
  videoConfig.value.path = video.filename
  ElMessage.success(`已选择: ${video.filename}`)
}

async function deleteVideo(filename) {
  try {
    await ElMessageBox.confirm(`确定要删除视频 "${filename}" 吗？`, '确认删除', {
      type: 'warning'
    })
    const res = await fetch(`/api/videos/${filename}`, { method: 'DELETE' })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('视频已删除')
      fetchVideos()
      if (videoConfig.value.path === filename) {
        videoConfig.value.path = ''
      }
    }
  } catch (e) {
    // 用户取消
  }
}

async function startFakeLive() {
  if (!selectedRoom.value.id) {
    ElMessage.warning('请选择直播间')
    return
  }
  if (!videoConfig.value.path) {
    ElMessage.warning('请选择或上传视频')
    return
  }
  
  if (isStreaming.value) {
    // 停止伪直播
    await stopFakeLive()
    return
  }
  
  starting.value = true
  
  try {
    // 配置伪直播
    const setupRes = await fetch(`/api/rooms/${selectedRoom.value.id}/fake-live/setup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        videoFile: videoConfig.value.path,
        loopCount: videoConfig.value.loopCount,
        autoStart: false
      })
    })
    const setupData = await setupRes.json()
    
    if (!setupData.success) {
      ElMessage.error(setupData.message || '配置失败')
      starting.value = false
      return
    }
    
    // 启动伪直播
    const startRes = await fetch(`/api/rooms/${selectedRoom.value.id}/fake-live/start`, {
      method: 'POST'
    })
    const startData = await startRes.json()
    
    if (startData.success) {
      isStreaming.value = true
      streamStartTime.value = new Date()
      startTimer()
      ElMessage.success('伪直播已启动')
    } else {
      ElMessage.error(startData.message || '启动失败')
    }
  } catch (e) {
    ElMessage.error('操作失败')
  } finally {
    starting.value = false
  }
}

async function stopFakeLive() {
  if (!selectedRoom.value.id) return
  
  try {
    const res = await fetch(`/api/rooms/${selectedRoom.value.id}/fake-live/stop`, {
      method: 'POST'
    })
    const data = await res.json()
    
    if (data.success) {
      isStreaming.value = false
      stopTimer()
      ElMessage.success('伪直播已停止')
    }
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

function startTimer() {
  if (durationTimer) clearInterval(durationTimer)
  durationTimer = setInterval(() => {
    if (streamStartTime.value) {
      const now = new Date()
      const diff = now - streamStartTime.value
      const hours = Math.floor(diff / 3600000)
      const minutes = Math.floor((diff % 3600000) / 60000)
      const seconds = Math.floor((diff % 60000) / 1000)
      streamDuration.value = 
        `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
    }
  }, 1000)
}

function stopTimer() {
  if (durationTimer) {
    clearInterval(durationTimer)
    durationTimer = null
  }
}

function copyToClipboard(text) {
  if (!text) {
    ElMessage.warning('没有可复制的内容')
    return
  }
  navigator.clipboard.writeText(text).then(() => {
    ElMessage.success('已复制到剪贴板')
  }).catch(() => {
    ElMessage.error('复制失败')
  })
}

function formatSize(bytes) {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

/**
 * 切换直播模式
 */
function onLiveModeChange() {
  currentStep.value = 0
  selectedRoom.value = { id: null }
  videoConfig.value = { path: '', loopCount: -1 }
  isStreaming.value = false
  
  // 更新直播间的直播模式
  if (currentLiveMode.value === 'normal') {
    ElMessage.info('已切换到正常直播模式，请选择直播间并配置推流')
  } else {
    ElMessage.info('已切换到伪直播模式，请选择直播间并上传视频')
  }
}

/**
 * 获取SRS配置
 */
async function fetchSrsConfig() {
  try {
    const res = await fetch('/api/srs/config')
    const data = await res.json()
    if (data.success) {
      srsConfig.value = data.data
      srsConfigured.value = true
    }
  } catch (e) {
    srsConfigured.value = false
    console.warn('SRS配置获取失败，使用默认配置')
  }
}

/**
 * 选择直播间（正常直播模式）
 */
async function selectRoomForNormal() {
  if (!selectedRoom.value.id) return
  
  try {
    // 更新直播间的直播模式
    await fetch(`/api/rooms/${selectedRoom.value.id}/live-mode`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ liveMode: 'normal' })
    })
    
    // 获取推流地址
    const res = await fetch(`/api/rooms/${selectedRoom.value.id}/stream-url`)
    const data = await res.json()
    
    if (data.success) {
      normalStreamConfig.value = {
        rtmpUrl: data.data.rtmpUrl,
        flvUrl: data.data.flvUrl,
        hlsUrl: data.data.hlsUrl,
        streamKey: data.data.streamKey
      }
      currentStep.value = 1
    }
  } catch (e) {
    ElMessage.error('获取推流地址失败')
  }
}

/**
 * 重新生成推流密钥
 */
async function regenerateStreamKey() {
  if (!selectedRoom.value.id) return
  
  try {
    await ElMessageBox.confirm('重新生成密钥后旧密钥将失效，确定继续？', '确认操作', {
      type: 'warning'
    })
    
    const res = await fetch(`/api/rooms/${selectedRoom.value.id}/regenerate-stream-key`, {
      method: 'POST'
    })
    const data = await res.json()
    
    if (data.success) {
      normalStreamConfig.value.streamKey = data.data.streamKey
      ElMessage.success('密钥已重新生成')
    } else {
      ElMessage.error(data.message || '操作失败')
    }
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error('操作失败')
    }
  }
}

/**
 * 开始正常直播
 */
async function startNormalLive() {
  if (!selectedRoom.value.id) {
    ElMessage.warning('请选择直播间')
    return
  }
  
  if (isStreaming.value) {
    // 停止直播
    await stopNormalLive()
    return
  }
  
  starting.value = true
  
  try {
    const res = await fetch(`/api/rooms/${selectedRoom.value.id}/start`, {
      method: 'POST'
    })
    const data = await res.json()
    
    if (data.success) {
      isStreaming.value = true
      streamStartTime.value = new Date()
      startTimer()
      ElMessage.success('直播已开启，请使用推流软件开始推流')
    } else {
      ElMessage.error(data.message || '操作失败')
    }
  } catch (e) {
    ElMessage.error('操作失败')
  } finally {
    starting.value = false
  }
}

/**
 * 停止正常直播
 */
async function stopNormalLive() {
  if (!selectedRoom.value.id) return
  
  try {
    const res = await fetch(`/api/rooms/${selectedRoom.value.id}/stop`, {
      method: 'POST'
    })
    const data = await res.json()
    
    if (data.success) {
      isStreaming.value = false
      stopTimer()
      ElMessage.success('直播已停止')
    }
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

onMounted(() => {
  fetchRooms()
  fetchVideos()
  fetchSrsConfig()
})

watch(selectedRoom, () => {
  if (selectedRoom.value.id && currentLiveMode.value === 'fake') {
    fetchStreamUrl()
  }
}, { deep: true })
</script>

<style scoped>
.stream-config { }
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
.steps {
  margin-bottom: 24px;
}
.step-card {
  min-height: 320px;
}
.step-card h3 {
  margin-bottom: 20px;
  color: #333;
}
.btn-group {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  margin-top: 16px;
}
.tip {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}
.mode-tip {
  font-size: 12px;
  color: #667eea;
  margin-top: 4px;
}
.command-preview {
  margin-top: 16px;
}
.command-preview .label {
  font-weight: bold;
  color: #333;
  margin-bottom: 8px;
}
.command {
  background: #1e1e2e;
  color: #cdd6f4;
  padding: 16px;
  border-radius: 8px;
  font-family: 'Courier New', monospace;
  font-size: 13px;
  overflow-x: auto;
  margin: 0;
}
.video-uploader {
  width: 100%;
}
.upload-progress {
  margin-top: 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}
.empty-videos {
  padding: 20px;
}
.video-list {
  max-height: 240px;
  overflow-y: auto;
}
.video-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: all 0.2s;
}
.video-item:hover {
  border-color: #667eea;
}
.video-item.selected {
  border-color: #667eea;
  background: #f0f4ff;
}
.video-thumbnail {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f0f0f0;
  border-radius: 8px;
  color: #666;
}
.video-info {
  flex: 1;
  min-width: 0;
}
.video-name {
  font-weight: 500;
  color: #333;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.video-size {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}
.preview-card { }
.preview-area {
  background: #1e1e2e;
  border-radius: 8px;
  aspect-ratio: 16/9;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  margin-bottom: 16px;
}
.preview-video {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.preview-placeholder {
  text-align: center;
  color: #666;
}
.preview-placeholder p {
  margin-top: 12px;
}
.preview-placeholder .tip {
  font-size: 12px;
}
.stream-info {
  display: flex;
  align-items: center;
  gap: 12px;
}
.stream-time {
  color: #666;
}
.guide-card {
  margin-top: 20px;
}
.guide-card h3 {
  margin-bottom: 16px;
  color: #333;
}

.mode-selector {
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
}

.mode-description {
  margin-top: 12px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 8px;
  border-left: 3px solid #667eea;
}

.mode-description p {
  margin: 0;
  font-size: 13px;
  color: #666;
  line-height: 1.6;
}

.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}

.srs-status {
  margin: 16px 0;
}

.obs-config {
  background: #f8f9fa;
  padding: 16px;
  border-radius: 8px;
  margin: 16px 0;
}

.obs-config p {
  margin: 0 0 12px 0;
  font-weight: 500;
}

.obs-config ol {
  margin: 0;
  padding-left: 20px;
  line-height: 1.8;
}

.obs-config code {
  background: #e4e7ed;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 12px;
}

.normal-live-preview {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.live-status {
  font-size: 18px;
  font-weight: 600;
  color: #67c23a;
}

.live-tip {
  font-size: 13px;
  color: #909399;
  margin: 0;
}
</style>
