// 全局变量保存事件处理函数
let selectionHandler = function() {
    console.log('selectionchangexxxxxx');
    var selection = window.getSelection();
    if (selection && selection.rangeCount > 0) {
        var text = selection.toString();
        if (text.length > 0) {
            var rect = selection.getRangeAt(0).getBoundingClientRect();
            var data = {
                text: text,
                x: rect.left + window.scrollX,
                y: rect.top + window.scrollY,
                width: rect.width,
                height: rect.height
            };
            console.log('selectionchangexxxxxx');
            window.webkit.messageHandlers.selectionHandler.postMessage(data);
        }
    }
};

function customSelectionChange() {
    document.documentElement.style.webkitUserSelect = 'text';
    document.documentElement.style.webkitTouchCallout = 'none';
    // 先移除旧事件
    document.removeEventListener('selectionchange', selectionHandler);
    // 再绑定新事件
    document.addEventListener('selectionchange', selectionHandler);
}

// 页面加载完成时调用
window.addEventListener('load', function() {
    customSelectionChange(); // 绑定选中事件
});

