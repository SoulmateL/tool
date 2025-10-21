# 一级标题 H1
## 二级标题 H2
### 三级标题 H3
#### 四级标题 H4
##### 五级标题 H5
###### 六级标题 H6

---

## 段落与文本样式

这是一个普通段落。

这是 **加粗文本**，这是 *斜体文本*，这是 ***粗斜体***。

这是 ~~删除线~~。

这是 `行内代码` 示例。

这是带有下标 H~2~O 和上标 X^2^ 的示例。

---

## 引用

> 这是一级引用。
>> 这是嵌套引用。
>>> 支持多层嵌套。

---

## 列表

### 无序列表

- 苹果
- 香蕉
  - 黄色香蕉
  - 青色香蕉
- 樱桃

### 有序列表

1. 第一项
2. 第二项
3. 第三项
   1. 子项 3.1
   2. 子项 3.2

---

## 任务清单

- [x] 完成基本语法
- [ ] 学习进阶语法
- [ ] 编写文档

---

## 代码块

### 行内代码
使用 `printf("Hello World");`

### 多行代码

```swift
// Swift 示例
func greet(name: String) {
    print("Hello, \(name)!")
}
greet(name: "Markdown")
```

```objective-c
// Objective-C 示例
- (void)sayHello {
    NSLog(@"Hello, Markdown!");
}
```

```python
# Python 示例
for i in range(3):
    print("Hello Markdown")
```

---

## 链接与图片

### 链接
[Markdown 官方文档](https://daringfireball.net/projects/markdown/)

[跳转到表格部分](#表格)

### 图片
![示例图片](https://cdn.jsdelivr.net/gh/adam-p/markdown-here@master/src/common/images/icon48.png "图标示例")

---

## 表格
```
| 姓名 | 年龄 | 职业 |
|------|------|------|
| 张三 | 25   | 程序员 |
| 李四 | 30   | 设计师 |
| 王五 | 28   | 产品经理 |
```
表格支持居中对齐：

| 左对齐 | 居中 | 右对齐 |
|:------ |:----:| ------:|
| A      | B    | C      |
| 1      | 2    | 3      |

---

## 分割线

---
***
___

---

## 脚注与引用

这是一个带脚注的文本[^1]。

[^1]: 脚注内容可以写在文末。

---

## 数学公式（LaTeX）

行内公式：$E = mc^2$
    $\\sqrt{3x-1}+(1+x)^2$

块级公式：
$$
\int_0^{\infty} e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

---

## HTML 混排

<p style="color:#007aff;">你也可以在 Markdown 中嵌入 HTML。</p>

<b>加粗标签</b>、<i>斜体标签</i>、<u>下划线</u> 都可以混用。

---

## 水平排版与引用图片

文字左对齐、居中、右对齐示例：

<p align="left">左对齐文本</p>
<p align="center">居中文本</p>
<p align="right">右对齐文本</p>

---

## 嵌入任务代码块

```bash
# 终端命令
echo "Markdown 全格式测试"
```

```json
{
  "name": "Markdown",
  "type": "example"
}
```

---

## Emoji 表情

😄 😎 🚀 ✅ ❌ ❤️ 👍

---

## 引用脚本与样式（HTML 模式）

<style>
p { color: #555; }
code { background: #f2f2f2; padding: 2px 4px; border-radius: 4px; }
</style>

---

## 最后

> Markdown 语法灵活强大，可轻松混合 HTML、LaTeX、代码与图片。
