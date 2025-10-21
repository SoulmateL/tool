function getPageHeight() {
    const container = document.getElementById('contents');
    if (!container) return document.documentElement.offsetHeight;

    const style = window.getComputedStyle(container);
    const paddingBottom = parseFloat(style.paddingBottom) || 0;

    const lastChild = container.lastElementChild;
    if (lastChild) {
        const rect = lastChild.getBoundingClientRect();
        // 取最后一个元素底部 + padding + scrollY
        const lastChildBottom = rect.bottom + paddingBottom + window.scrollY;

        // 同时取 HTML 根元素高度，保证高度不小
        return Math.max(lastChildBottom, document.documentElement.offsetHeight);
    }

    // 容器为空时，返回容器高度 + padding 或 HTML 高度
    return Math.max(container.offsetHeight + paddingBottom, document.documentElement.offsetHeight);
}

// 发送高度给原生
function sendHeight() {
    const height = getPageHeight();
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.updateHeight) {
        window.webkit.messageHandlers.updateHeight.postMessage(height);
    }
}

// 页面加载完成发送一次
window.addEventListener('load', sendHeight);

// 横竖屏或窗口大小变化时发送高度
window.addEventListener('resize', sendHeight);

// 监听 DOM 内容变化
const observer = new MutationObserver(sendHeight);
observer.observe(document.body, { childList: true, subtree: true, characterData: true });
