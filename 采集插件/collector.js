// ============================================================
// collector.js - 电商页面采集器
// 在1688/淘宝/亚马逊/速卖通产品页注入，提取产品信息
// ============================================================

(function () {
  'use strict';

  // 避免重复注入
  if (window.__chuiCollectorInjected) return;
  window.__chuiCollectorInjected = true;

  const SYS_URL = 'http://localhost:5500/';
  const STORAGE_KEY = 'chui_collect_data';

  // ============================================================
  // 平台检测
  // ============================================================
  function detectPlatform() {
    const host = location.hostname;
    if (host.includes('1688.com')) return '1688';
    if (host.includes('taobao.com') || host.includes('tmall.com')) return 'taobao';
    if (host.includes('amazon.com') || host.includes('amazon.co.jp') || host.includes('amazon.co.uk') || host.includes('amazon.de')) return 'amazon';
    if (host.includes('aliexpress.com')) return 'aliexpress';
    return 'unknown';
  }

  // ============================================================
  // 平台选择器映射
  // ============================================================
  const SELECTORS = {
    '1688': {
      title: [
        'h1[data-testid="offer-title"]',
        '.offer-title-text',
        'h1.offer-title',
        '.title-text',
        'h1'
      ],
      price: [
        '.offer-price .price',
        '.price-original',
        '.price-value',
        '[class*="price"] [class*="num"]'
      ],
      shopName: [
        '.company-name',
        '.shop-name-text',
        '[data-testid="company-name"]',
        '.shop-info .name',
        'h1[title]',
        'h1[data-spm-anchor-id*="shopNavigation"]'
      ],
      mainImage: [
        '.main-image img',
        '[data-testid="main-image"] img',
        '.detail-gallery img:first-child'
      ],
      category: [
        '[data-testid="breadcrumb"] span',
        '.breadcrumb a',
        '.nav-crumb a'
      ],
      specs: [
        '.sku-item',
        '.offer-sku-item',
        '[data-testid="sku-item"]'
      ],
      // 供应商专属字段
      contact: [
        '.contact-name',
        '.seller-contact .name',
        '.contact-person'
      ],
      phone: [
        '.contact-phone',
        '.seller-contact .phone',
        '.contact-tel',
        '[class*="phone"]'
      ],
      address: [
        '.company-location',
        '.company-address',
        '.location-text',
        '.address-info'
      ],
      location: [
        '.company-location',
        '.location-text',
        '.company-area',
        '[class*="location"]'
      ]
    },
    'amazon': {
      title: ['#productTitle', '#title', 'h1#title'],
      price: [
        '.a-price .a-offscreen',
        '#priceblock_ourprice',
        '.a-price-whole',
        '#corePrice_desktop .a-price'
      ],
      shopName: ['#bylineInfo', '#brandByline_feature_div', '.po-brand a'],
      mainImage: ['#landingImage', '#imgTagWrapperId img', '.imgTagWrapper img'],
      category: ['#wayfinding-breadcrumbs_feature_div a', '#breadcrumb a'],
      specs: ['#productOverview_feature_div tr', '#detailBullets_feature_div li'],
      contact: ['.seller-name', '#sellerProfileTriggerId'],
      phone: [],
      address: ['.offer-location', '#salesRank'],
      location: ['.offer-location', '#olpProductDetails .a-section']
    },
    'taobao': {
      title: ['h1[data-spm="1000983"]', '.tb-main-title', 'h1'],
      price: ['.tb-rmb-num', '.tm-price', '[class*="Price"]'],
      shopName: ['.tb-shop-name', '.slogo-shopname', '.shop-name'],
      mainImage: ['#J_ImgBooth', '.tb-booth img', '#J_UlThumb img:first-child'],
      category: ['.tb-breadcrumb a', '#J_BreadCrumb a'],
      specs: ['.tb-sku li', '.J_TSaleProp li'],
      contact: ['.seller-info .name', '.ww-light'],
      phone: [],
      address: ['.tb-seller-location', '.seller-info .location'],
      location: ['.tb-seller-location', '.seller-info .location']
    },
    'aliexpress': {
      title: ['.product-title-text', 'h1[data-pl="product-title"]'],
      price: ['.product-price-value', '.product-price-current'],
      shopName: ['.store-name', '.shop-title'],
      mainImage: ['.images-view-item img', '.image-view img'],
      category: ['.breadcrumb a'],
      specs: ['.sku-property-item'],
      contact: ['.store-name'],
      phone: [],
      address: ['.store-address', '.store-location'],
      location: ['.store-address', '.store-location']
    }
  };

  const PLATFORM_LABELS = {
    '1688': '1688',
    'amazon': 'Amazon',
    'taobao': '淘宝',
    'aliexpress': '速卖通',
    'unknown': '未知平台'
  };

  // ============================================================
  // DOM 提取工具
  // ============================================================
  function queryFirst(selectors) {
    for (const sel of selectors) {
      try {
        const el = document.querySelector(sel);
        if (el) return el;
      } catch (e) { /* 选择器无效，跳过 */ }
    }
    return null;
  }

  function queryText(selectors) {
    const el = queryFirst(selectors);
    return el ? el.textContent.trim() : '';
  }

  function queryAllText(selectors) {
    const els = [];
    for (const sel of selectors) {
      try {
        const found = document.querySelectorAll(sel);
        if (found.length) {
          found.forEach(el => {
            const t = el.textContent.trim();
            if (t && !els.includes(t)) els.push(t);
          });
          break;
        }
      } catch (e) { /* skip */ }
    }
    return els;
  }

  // ============================================================
  // 数据提取
  // ============================================================
  function extract(platform) {
    const s = SELECTORS[platform] || SELECTORS['1688'];

    // 标题
    const title = queryText(s.title);

    // 价格
    const price = queryText(s.price);

    // 店铺
    const shopName = queryText(s.shopName);

    // 主图
    const imgEl = queryFirst(s.mainImage);
    const imageUrl = imgEl ? (imgEl.src || imgEl.getAttribute('data-src') || '') : '';

    // 类目（面包屑）
    const cats = queryAllText(s.category);
    const cat1 = cats.length > 0 ? cats[0] : '';
    const cat2 = cats.length > 1 ? cats.slice(0, -1).join(' > ') : '';
    const category = cats.join(' > ');

    // 规格
    const specEls = [];
    for (const sel of s.specs) {
      try {
        const found = document.querySelectorAll(sel);
        if (found.length) {
          found.forEach(el => specEls.push(el.textContent.trim()));
          break;
        }
      } catch (e) { /* skip */ }
    }
    const specs = specEls.slice(0, 20).join('; ');

    return {
      title,
      price,
      shopName,
      imageUrl,
      category,
      cat1,
      cat2,
      specs,
      url: location.href,
      platform: PLATFORM_LABELS[platform] || platform,
      collectedAt: new Date().toISOString(),
      // 供应商专属字段
      contact: queryText(s.contact||[]),
      phone: queryText(s.phone||[]),
      address: queryText(s.address||[]),
      location: queryText(s.location||[])
    };
  }

  // ============================================================
  // UI：注入浮动采集按钮
  // ============================================================
  function injectButton(platform) {
    if (document.getElementById('chui-collect-btn')) return;

    const btn = document.createElement('div');
    btn.id = 'chui-collect-btn';
    btn.title = '采集到垂类产品管理系统';
    btn.innerHTML = '📋 采集';
    Object.assign(btn.style, {
      position: 'fixed',
      bottom: '30px',
      right: '30px',
      zIndex: '999999',
      padding: '12px 20px',
      background: 'linear-gradient(135deg, #4361ee, #3a0ca3)',
      color: '#fff',
      borderRadius: '28px',
      cursor: 'pointer',
      fontSize: '15px',
      fontWeight: '600',
      fontFamily: 'system-ui, sans-serif',
      boxShadow: '0 4px 20px rgba(67,97,238,0.45)',
      transition: 'all 0.2s ease',
      display: 'flex',
      alignItems: 'center',
      gap: '6px',
      userSelect: 'none',
      border: 'none',
      letterSpacing: '0.5px'
    });

    btn.addEventListener('mouseenter', () => {
      btn.style.transform = 'translateY(-3px)';
      btn.style.boxShadow = '0 8px 30px rgba(67,97,238,0.55)';
    });
    btn.addEventListener('mouseleave', () => {
      btn.style.transform = 'translateY(0)';
      btn.style.boxShadow = '0 4px 20px rgba(67,97,238,0.45)';
    });

    btn.addEventListener('click', async () => {
      btn.innerHTML = '⏳ 采集中...';
      btn.style.opacity = '0.7';

      try {
        const data = extract(platform);
        await chrome.storage.local.set({ [STORAGE_KEY]: data });
        
        btn.innerHTML = '✅ 已采集';
        btn.style.background = 'linear-gradient(135deg, #10b981, #059669)';
        
        // 小提示
        showToast(`已采集「${data.title.slice(0, 20)}…」\n请切换到垂类系统页面填写`);

        setTimeout(() => {
          btn.innerHTML = '📋 采集';
          btn.style.background = 'linear-gradient(135deg, #4361ee, #3a0ca3)';
          btn.style.opacity = '1';
        }, 2500);
      } catch (e) {
        btn.innerHTML = '❌ 失败';
        showToast('采集失败: ' + e.message);
        setTimeout(() => {
          btn.innerHTML = '📋 采集';
          btn.style.opacity = '1';
        }, 2000);
      }
    });

    document.body.appendChild(btn);
  }

  // ============================================================
  // Toast 提示
  // ============================================================
  function showToast(msg) {
    const existing = document.getElementById('chui-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.id = 'chui-toast';
    toast.textContent = msg;
    Object.assign(toast.style, {
      position: 'fixed',
      bottom: '100px',
      right: '30px',
      zIndex: '9999999',
      padding: '14px 22px',
      background: 'rgba(0,0,0,0.88)',
      color: '#fff',
      borderRadius: '12px',
      fontSize: '14px',
      fontWeight: '500',
      fontFamily: 'system-ui, sans-serif',
      boxShadow: '0 8px 30px rgba(0,0,0,0.3)',
      whiteSpace: 'pre-line',
      animation: 'chuiSlideIn 0.3s ease',
      pointerEvents: 'none'
    });

    // 注入动画 CSS
    if (!document.getElementById('chui-toast-style')) {
      const style = document.createElement('style');
      style.id = 'chui-toast-style';
      style.textContent = `
        @keyframes chuiSlideIn {
          from { opacity: 0; transform: translateY(20px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `;
      document.head.appendChild(style);
    }

    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 3000);
  }

  // ============================================================
  // 入口
  // ============================================================
  function init() {
    const platform = detectPlatform();
    console.log('[垂类采集] 检测到平台:', platform);

    if (platform === 'unknown') return;

    // 等待页面完全加载后注入按钮
    if (document.readyState === 'complete') {
      setTimeout(() => injectButton(platform), 800);
    } else {
      window.addEventListener('load', () => {
        setTimeout(() => injectButton(platform), 800);
      });
    }
  }

  init();
})();
