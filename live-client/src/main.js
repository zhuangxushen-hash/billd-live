import { createApp } from 'vue'
import App from './App.vue'
import RoomList from './views/RoomList.vue'
import RoomPlayer from './views/RoomPlayer.vue'

const app = createApp(App)

// 简单的路由
app.component('RoomList', RoomList)
app.component('RoomPlayer', RoomPlayer)

app.mount('#app')
