// ============================================================
// receiver.js - 系统页面接收器
// 在垂类产品管理系统页面注入，监听 chrome.storage 变化
// 通过 window.postMessage 把采集数据传给前端 JS
// ============================================================

(function () {
  'use strict';

  if (window.__chuiReceiverInjected) return;
  window.__chuiReceiverInjected = true;

  const STORAGE_KEY = 'chui_collect_data';

  // ============================================================
  // 监听 storage 变化 → 转发给页面
  // ============================================================
  chrome.storage.onChanged.addListener((changes, namespace) => {
    if (namespace !== 'local') return;
    if (!changes[STORAGE_KEY]) return;
    
    const newValue = changes[STORAGE_KEY].newValue;
    if (!newValue) return;

    console.log('[垂类接收] 收到采集数据:', newValue);

    // 通过 postMessage 发送给页面
    window.postMessage({
      source: 'chui-collector-extension',
      type: 'collect-data',
      data: newValue
    }, '*');

    // 消费后清除
    chrome.storage.local.remove(STORAGE_KEY);
  });

  // ============================================================
  // 页面启动时检查是否有未消费的采集数据
  // ============================================================
  chrome.storage.local.get([STORAGE_KEY], (result) => {
    if (result[STORAGE_KEY]) {
      console.log('[垂类接收] 发现待处理数据:', result[STORAGE_KEY]);
      
      window.postMessage({
        source: 'chui-collector-extension',
        type: 'collect-data',
        data: result[STORAGE_KEY]
      }, '*');

      chrome.storage.local.remove(STORAGE_KEY);
    }
  });

  // ============================================================
  // 页面重新可见时也检查一次（防止后台标签页错过 onChanged）
  // ============================================================
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      chrome.storage.local.get([STORAGE_KEY], (result) => {
        if (result[STORAGE_KEY]) {
          console.log('[垂类接收] 切回前台发现待处理数据');
          window.postMessage({
            source: 'chui-collector-extension',
            type: 'collect-data',
            data: result[STORAGE_KEY]
          }, '*');
          chrome.storage.local.remove(STORAGE_KEY);
        }
      });
    }
  });

  console.log('[垂类接收] 已就绪');
})();
