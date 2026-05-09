<script setup lang="ts">
import { computed } from 'vue'
import api from '@/api'


interface RoomData {
  roomClients: number
  roomLastUpdatedAt: string | null
  roomArkhamGameId: string
}

const props = defineProps<{
  room: RoomData
}>()

const lastUpdated = computed(() => props.room.roomLastUpdatedAt ? props.room.roomLastUpdatedAt : '已删除')
const deleted = computed(() => lastUpdated.value === '已删除')

async function deleteRoom() {
  await api.delete(`admin/rooms/${props.room.roomArkhamGameId}`)
  window.location.reload()
}

</script>

<template>
  <div class='room'>
    <span>{{room.roomClients}}</span>
    <span>{{lastUpdated}}</span>
    <span><router-link :to="`/admin/games/${room.roomArkhamGameId}`">查看</router-link></span>
    <span v-if="deleted"><a href='#' @click.prevent="deleteRoom">删除</a></span>
  </div>
</template>

<style scoped>
.room {
  padding: 20px;
  border-bottom: 1px solid var(--line);
  display: flex;
  *  {
    flex: 1;
  }
}
</style>
