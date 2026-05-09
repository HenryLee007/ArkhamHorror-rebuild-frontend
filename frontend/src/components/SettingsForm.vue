<script lang="ts" setup>
import { ref } from 'vue';
import type { User } from '@/types';
import { useDbCardStore } from '@/stores/dbCards'
import { checkImageExists } from '@/arkham/helpers'

const props = defineProps<{
  user: User
  updateBeta: (setting: boolean) => void
  deleteAccount: () => void
}>()

const store = useDbCardStore()
const beta = ref(props.user.beta ? "On" : "Off")
const showDeleteConfirm = ref(false)

const betaUpdate = async () => props.updateBeta(beta.value == "On")

const updateLanguage = async (a: Event) => {
  const target = a.target as HTMLInputElement;
  localStorage.setItem('language', target.value)
  await store.initDbCards()
  await checkImageExists()
}
</script>

<template>
  <div class="page-container">
    <div class="page-content column">
      <h2 class="title">{{$t('settings')}}</h2>

      <section class="box column">
        <h3>{{$t('language')}}</h3>
        <p>这会更改卡牌和应用的显示语言；如果所选语言缺少某张卡牌或某段文本，将默认显示英文。</p>
        <select v-model="$i18n.locale" @change="updateLanguage">
          <option value="en">英语</option>
          <option value="zh">中文</option>
        </select>
      </section>

      <section class="box column">
        <h3>加入 Beta 测试</h3>
        <p>Beta 功能可能很不稳定，游戏也可能无法恢复。只有在你愿意提供反馈时才建议开启。</p>
        <div class="row">
          <label class="radio-label">
            <input type="radio" name="beta" value="On" v-model="beta" @change="betaUpdate" />
            开启
          </label>
          <label class="radio-label">
            <input type="radio" name="beta" value="Off" v-model="beta" @change="betaUpdate" />
            关闭
          </label>
        </div>
      </section>

      <section class="box column danger-zone">
        <h3 class="danger-title">危险区域</h3>
        <p>永久删除你的账号以及所有相关数据，包括游戏和牌组。<strong>此操作无法撤销。</strong></p>
        <div v-if="!showDeleteConfirm">
          <button class="btn-danger" @click="showDeleteConfirm = true">删除账号</button>
        </div>
        <div v-else class="column">
          <p class="warning">你确定吗？你的所有游戏、牌组和账号数据都会永久丢失，且无法恢复。</p>
          <div class="row">
            <button class="btn-danger" @click="props.deleteAccount()">是的，永久删除我的账号</button>
            <button @click="showDeleteConfirm = false">取消</button>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
h3 {
  font-size: 1.1em;
  font-weight: bold;
  color: var(--title);
  text-transform: uppercase;
  font-family: teutonic, sans-serif;
  font-size: 1.4em;
}

p {
  color: var(--title);
  opacity: 0.8;
}

select {
  background-color: var(--background-dark);
  color: var(--title);
  border: 1px solid var(--box-border);
  border-radius: 4px;
  padding: 6px 10px;
  font-size: 1em;
  width: fit-content;
}

input[type="radio"] {
  display: unset;
  accent-color: var(--spooky-green);
}

.radio-label {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--title);
  cursor: pointer;
}

.danger-zone {
  border-color: var(--delete);
}

.danger-title {
  color: var(--delete);
}

.btn-danger {
  background-color: var(--delete);
  color: white;
  border: none;
  padding: 8px 16px;
  cursor: pointer;
  border-radius: 4px;
  font-size: 1em;
  text-transform: uppercase;
}

.btn-danger:hover {
  background-color: #a32929;
}

.warning {
  color: var(--delete);
  font-weight: bold;
}
</style>
