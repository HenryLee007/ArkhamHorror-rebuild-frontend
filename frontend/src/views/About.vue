<script setup lang="ts">
</script>
<template>
  <div class="page-container">
    <div class="page-content column">
      <section class="column">
        <h2 class="title">{{$t('about.copyright.title')}}</h2>
        <div class="box column">
          <p>{{$t('about.copyright.text1')}}</p>
          <p>{{$t('about.copyright.text2')}}</p>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
@media (max-width: 768px) {
  .page-content {
    width: 100%;
    padding: 0 12px;
    box-sizing: border-box;
  }
}
</style>
