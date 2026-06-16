// popup.js - 插件弹出窗口
// 显示采集数据状态 + 一键打开系统页面

(function () {
  const STORAGE_KEY = 'chui_collect_data';
  const SYS_URL = 'http://localhost:5500/%E5%89%8D%E7%AB%AF_%E4%BA%A7%E5%93%81%E7%AE%A1%E7%90%86%E7%B3%BB%E7%BB%9F.html';

  // 刷新状态
  function refreshStatus() {
    chrome.storage.local.get([STORAGE_KEY], (result) => {
      const badge = document.getElementById('pending-badge');
      const summary = document.getElementById('data-summary');
      const preview = document.getElementById('data-preview');
      if (!badge) return;
      
      const data = result[STORAGE_KEY];
      if (data && data.title) {
        badge.textContent = '✅ 有数据';
        badge.className = 'badge badge-active';
        if (summary) {
          summary.textContent = '来自 ' + (data.platform || '未知') + ' · ' + data.title.slice(0, 15) + '…';
        }
        if (preview) {
          preview.style.display = 'block';
          preview.innerHTML = `
            <div><span class="label">供应商：</span>${esc(data.shopName||data.title||'未获取')}</div>
            <div><span class="label">联系人：</span>${esc(data.contact||'未获取')}</div>
            <div><span class="label">联系方式：</span>${esc(data.phone||'未获取')}</div>
            <div><span class="label">产品种类：</span>${esc(data.category||'未获取')}</div>
            <div><span class="label">地址：</span>${esc(data.location||data.address||'未获取')}</div>
            <div style="margin-top:4px;font-size:11px;color:#6b7280;">切换回系统页面即可自动填表</div>
          `;
        }
      } else {
        badge.textContent = '暂无数据';
        badge.className = 'badge badge-none';
        if (summary) summary.textContent = '';
        if (preview) preview.style.display = 'none';
      }
    });
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // 打开系统页面
  document.getElementById('btn-open-system').addEventListener('click', () => {
    chrome.tabs.create({ url: SYS_URL });
  });

  // 手动刷新
  document.getElementById('btn-check-data').addEventListener('click', refreshStatus);

  // 初始加载
  document.addEventListener('DOMContentLoaded', refreshStatus);
})();
