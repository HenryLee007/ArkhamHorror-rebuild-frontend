<script lang="ts" setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { newDeck, validateDeck } from '@/arkham/api'
import { processArkhamBuildDeck } from '@/arkham/helpers'
import type { ArkhamDbDecklist, Meta } from '@/arkham/types/Deck'

const STORAGE_KEY = 'arkham-build-import-payload'
const FALLBACK_DECK_NAME = 'Imported arkham.build deck'

interface ImportPayload {
  source?: unknown
  sourceUrl?: unknown
  deck?: unknown
}

interface UnimplementedCardError {
  tag?: string
  contents?: string
}

type ArkhamBuildDeckRecord = Record<string, unknown> & {
  slots?: Record<string, number>
}

const router = useRouter()
const deckList = ref<ArkhamDbDecklist | null>(null)
const errors = ref<string[]>([])
const message = ref('正在读取 arkham.build 导入数据...')
const saving = ref(false)
const validating = ref(false)
const sourceUrl = ref<string | null>(null)

const canSave = computed(() => deckList.value !== null && errors.value.length === 0 && !saving.value)

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function asString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null
}

function asNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function asSlots(value: unknown): Record<string, number> {
  if (!isRecord(value)) return {}

  return Object.entries(value).reduce<Record<string, number>>((acc, [key, amount]) => {
    if (typeof amount === 'number' && Number.isFinite(amount)) acc[key] = amount
    return acc
  }, {})
}

function asMeta(value: unknown): Meta | undefined {
  if (isRecord(value)) return value as Meta
  if (typeof value !== 'string') return undefined

  try {
    const parsed = JSON.parse(value)
    return isRecord(parsed) ? parsed as Meta : undefined
  } catch (_e) {
    return undefined
  }
}

function responseErrors(err: unknown): string[] {
  const data = (err as { response?: { data?: unknown } }).response?.data
  if (!Array.isArray(data)) return []

  return data.map((entry: UnimplementedCardError) =>
    entry.contents ? `未实装卡牌：${entry.contents}` : '未实装卡牌'
  )
}

function errorMessages(err: unknown, fallback: string): string[] {
  const apiErrors = responseErrors(err)
  if (apiErrors.length > 0) return apiErrors
  return err instanceof Error ? [err.message] : [fallback]
}

function buildDeckList(payload: ImportPayload): ArkhamDbDecklist {
  if (!isRecord(payload.deck)) {
    throw new Error('arkham.build 没有提供可导入的牌组数据。')
  }

  const rawSourceUrl = asString(payload.sourceUrl)
  const rawDeck: ArkhamBuildDeckRecord = { ...payload.deck, slots: asSlots(payload.deck.slots) }
  const processed = processArkhamBuildDeck(rawDeck, rawSourceUrl ?? '/build')
  const name = asString(processed['name']) ?? FALLBACK_DECK_NAME
  const investigatorCode = asString(processed['investigator_code'])
  const slots = asSlots(processed.slots)

  if (!investigatorCode) {
    throw new Error('牌组缺少调查员代码，无法导入。')
  }

  if (Object.keys(slots).length === 0) {
    throw new Error('牌组没有可导入的卡牌。')
  }

  sourceUrl.value = rawSourceUrl ?? asString(processed['url'])

  const result: ArkhamDbDecklist = {
    id: asString(processed['id']) ?? asNumber(processed['id']) ?? Date.now().toString(),
    url: sourceUrl.value,
    name,
    investigator_code: investigatorCode,
    investigator_name: asString(processed['investigator_name']),
    slots,
    sideSlots: asSlots(processed['sideSlots']),
  }

  const tabooId = asNumber(processed['taboo_id'])
  if (tabooId !== null) result.taboo_id = tabooId

  const meta = asMeta(processed['meta'])
  if (meta) result.meta = meta

  return result
}

async function loadPayload() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) throw new Error('没有找到 arkham.build 导入数据，请回到组卡器重新点击“导入到游戏”。')

    const parsed = JSON.parse(raw) as ImportPayload
    const nextDeckList = buildDeckList(parsed)
    deckList.value = nextDeckList

    validating.value = true
    await validateDeck(nextDeckList)
    errors.value = []
    message.value = '牌组已通过当前项目验证，可以保存。'
  } catch (err) {
    errors.value = errorMessages(err, '导入验证失败，请检查当前项目是否已实装这些卡牌。')
    message.value = '暂时无法导入这个牌组。'
  } finally {
    validating.value = false
  }
}

async function saveDeck() {
  if (!deckList.value || !canSave.value) return

  saving.value = true
  errors.value = []
  try {
    const created = await newDeck(
      String(deckList.value.id),
      deckList.value.name,
      deckList.value.url,
      deckList.value
    )
    localStorage.removeItem(STORAGE_KEY)
    router.push({ name: 'Deck', params: { deckId: created.id } })
  } catch (err) {
    errors.value = errorMessages(err, '保存失败，请稍后重试。')
  } finally {
    saving.value = false
  }
}

loadPayload()
</script>

<template>
  <main class="arkham-build-import">
    <section class="panel">
      <header class="header">
        <div>
          <p class="eyebrow">arkham.build</p>
          <h1>导入牌组</h1>
        </div>
        <a v-if="sourceUrl" class="secondary-link" :href="sourceUrl">返回组卡器</a>
      </header>

      <div v-if="deckList" class="summary">
        <h2>{{ deckList.name }}</h2>
        <dl>
          <div>
            <dt>调查员</dt>
            <dd>{{ deckList.investigator_name || deckList.investigator_code }}</dd>
          </div>
          <div>
            <dt>卡牌数量</dt>
            <dd>{{ Object.values(deckList.slots).reduce((sum, amount) => sum + amount, 0) }}</dd>
          </div>
        </dl>
      </div>

      <p class="message" :class="{ error: errors.length > 0 }">{{ validating ? '正在验证牌组...' : message }}</p>

      <div v-if="errors.length > 0" class="errors">
        <p>无法保存牌组：</p>
        <ul>
          <li v-for="(error, idx) in errors" :key="idx">{{ error }}</li>
        </ul>
      </div>

      <div class="actions">
        <button class="primary" :disabled="!canSave" @click="saveDeck">
          {{ saving ? '保存中...' : '保存到我的牌组' }}
        </button>
        <router-link class="secondary" to="/decks">返回我的牌组</router-link>
      </div>
    </section>
  </main>
</template>

<style scoped>
.arkham-build-import {
  min-height: calc(100vh - var(--nav-height));
  display: grid;
  place-items: center;
  padding: 32px 16px;
  color: #f0f0f0;
}

.panel {
  width: min(680px, 100%);
  background: var(--box-background);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 8px;
  padding: 24px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35);
}

.header {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: flex-start;
}

.eyebrow {
  margin: 0 0 6px;
  color: var(--spooky-green);
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

h1,
h2 {
  margin: 0;
  color: var(--title);
}

.secondary-link,
.secondary {
  color: #9aa8c8;
  text-decoration: none;
}

.summary {
  margin-top: 24px;
  padding-top: 18px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}

dl {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin: 18px 0 0;
}

dt {
  color: #8a93a8;
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

dd {
  margin: 4px 0 0;
  color: #fff;
  font-weight: 700;
}

.message {
  margin: 22px 0 0;
  color: #c8d0df;
}

.message.error {
  color: #ffb4b4;
}

.errors {
  margin-top: 14px;
  padding: 14px 16px;
  background: rgba(100, 0, 0, 0.45);
  border: 1px solid rgba(255, 90, 90, 0.22);
  border-radius: 6px;
}

.errors p {
  margin: 0 0 8px;
}

.errors ul {
  margin: 0;
  padding-left: 20px;
}

.actions {
  display: flex;
  gap: 14px;
  align-items: center;
  margin-top: 24px;
}

.primary {
  min-height: 44px;
  padding: 0 18px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 5px;
  background: rgba(110, 134, 64, 0.95);
  color: #fff;
  font-weight: 700;
  cursor: pointer;
}

.primary:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

@media (max-width: 560px) {
  .header,
  .actions {
    flex-direction: column;
    align-items: stretch;
  }

  dl {
    grid-template-columns: 1fr;
  }
}
</style>
