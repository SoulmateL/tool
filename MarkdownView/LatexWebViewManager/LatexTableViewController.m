//
//  LatexTableViewController.m
//

#import "LatexTableViewController.h"

@interface LatexTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *formulaImageView;
@end

@implementation LatexTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _formulaImageView = [[UIImageView alloc] init];
        _formulaImageView.contentMode = UIViewContentModeScaleAspectFit;
        _formulaImageView.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_formulaImageView];
    }
    return self;
}

// 设置 frame 或使用 AutoLayout
- (void)layoutSubviews {
    [super layoutSubviews];
    if (_formulaImageView.image) {
        CGSize size = _formulaImageView.image.size;
        size = CGSizeMake(size.width/2, size.height/2);
        CGFloat maxWidth = self.contentView.frame.size.width - 32;
        CGFloat scale = MIN(1.0, maxWidth / size.width);
        _formulaImageView.frame = CGRectMake(16, 8, size.width * scale, size.height * scale);
    }
}

@end


@interface LatexTableViewController ()

// 存储公式文本
@property (nonatomic, strong) NSArray<NSString *> *latexArray;
@property (nonatomic, strong) NSArray<NSString *> *latexArray1;

// 存储渲染好的图片
@property (nonatomic, strong) NSMutableArray<UIImage *> *images;

@end

@implementation LatexTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"LaTeX 渲染示例";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80;
    
    // 示例公式
    self.latexArray = @[
        // 1️⃣ 麦克斯韦方程组（微分形式）
        @"\\begin{cases} \\nabla \\cdot \\vec{E} = \\frac{\\rho}{\\varepsilon_0} \\\\ \\nabla \\cdot \\vec{B} = 0 \\\\ \\nabla \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t} \\\\ \\nabla \\times \\vec{B} = \\mu_0 \\vec{J} + \\mu_0 \\varepsilon_0 \\frac{\\partial \\vec{E}}{\\partial t} \\end{cases}",

        // 2️⃣ 四元数旋转
        @"\\displaystyle q = \\cos \\frac{\\theta}{2} + (xi + yj + zk) \\sin \\frac{\\theta}{2}",

        // 3️⃣ 分段函数（带绝对值）
        @"f(x) = \\begin{cases} x^2, & x \\ge 0 \\\\ -|x|, & x < 0 \\end{cases}",

        // 4️⃣ 张量指标升降
        @"A^{\\mu} = g^{\\mu\\nu} A_{\\nu}",

        // 5️⃣ 卷积定义
        @"(f * g)(t) = \\int_{-\\infty}^{\\infty} f(\\tau) g(t - \\tau) \\, d\\tau",

        // 6️⃣ 独立同分布样本似然
        @"L(\\theta; x_1, \\dots, x_n) = \\prod_{i=1}^{n} f(x_i | \\theta)",

        // 7️⃣ 高斯分布概率密度
        @"p(x) = \\frac{1}{\\sqrt{2\\pi\\sigma^2}} e^{-\\frac{(x - \\mu)^2}{2\\sigma^2}}",

        // 8️⃣ 傅里叶级数展开
        @"f(x) = a_0 + \\sum_{n=1}^{\\infty} \\left[ a_n \\cos(n\\omega_0 x) + b_n \\sin(n\\omega_0 x) \\right]",

        // 9️⃣ 微分方程
        @"y'' + p(x)y' + q(x)y = 0",

        // 🔟 复平面积分路径
        @"\\oint_{|z|=1} \\frac{1}{z^2 + 1} \\, dz = 0"
    ];

    self.latexArray1 = @[
        // 1️⃣ 偏微分方程（波动方程）
        @"\\frac{\\partial^2 u}{\\partial t^2} = c^2 \\nabla^2 u",

        // 2️⃣ Navier–Stokes 方程
        @"\\rho \\left( \\frac{\\partial \\vec{v}}{\\partial t} + (\\vec{v}\\cdot\\nabla)\\vec{v} \\right) = -\\nabla p + \\mu \\nabla^2 \\vec{v} + \\vec{f}",

        // 3️⃣ 拉普拉斯变换
        @"\\mathcal{L}\\{f(t)\\} = \\int_{0}^{\\infty} f(t)e^{-st} \\, dt",

        // 4️⃣ 期望与方差
        @"E[X] = \\sum_i x_i p_i, \\quad Var(X) = E[X^2] - (E[X])^2",

        // 5️⃣ 泰勒展开（高阶）
        @"f(x) = f(a) + f'(a)(x-a) + \\frac{f''(a)}{2!}(x-a)^2 + \\cdots + \\frac{f^{(n)}(a)}{n!}(x-a)^n",

        // 6️⃣ 熵定义（信息论）
        @"H(X) = - \\sum_{i=1}^{n} p(x_i) \\log p(x_i)",

        // 7️⃣ 条件概率链式法则
        @"P(A_1, A_2, \\dots, A_n) = P(A_1) \\prod_{i=2}^{n} P(A_i | A_1, \\dots, A_{i-1})",

        // 8️⃣ Beta 函数与 Gamma 函数关系
        @"B(x, y) = \\frac{\\Gamma(x) \\Gamma(y)}{\\Gamma(x+y)}",

        // 9️⃣ 特征值方程
        @"A\\vec{v} = \\lambda \\vec{v}",

        // 🔟 多项式生成函数
        @"G(x) = \\sum_{n=0}^{\\infty} a_n x^n"
    ];


    
    // 初始化图片数组
    self.images = [NSMutableArray array];

    
    // 调用渲染
    __weak typeof(self) weakSelf = self;
    NSLog(@"~~~~~~~~~~~~~~~~~~%@",[NSDate date]);
    [[LatexSwiftManager shared] renderFormulas:self.latexArray completion:^(NSArray<UIImage *> *images) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSLog(@"~~~~~~~~~~~~~~~~~~%@",[NSDate date]);
        // 更新图片数组
        [self.images addObjectsFromArray:images];
        
        // 刷新表格
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
    MarkdownView *md = [[MarkdownView alloc] initWithMarkdownStyle:YES];
    [[LatexSwiftManager shared] renderFormulas:self.latexArray1 completion:^(NSArray<UIImage *> *images) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSLog(@"~~~~~~~~~~~~~~~~~~%@",[NSDate date]);
        // 更新图片数组
        [self.images addObjectsFromArray:images];
        
        // 刷新表格
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.images.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIImage *img = self.images[indexPath.row];
    if (!img) return 44;
    
    CGFloat maxWidth = tableView.frame.size.width - 32;
    CGFloat scale = MIN(1.0, maxWidth / img.size.width);
    return img.size.height * scale + 16; // 上下边距
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"LatexCell";
    LatexTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[LatexTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    cell.formulaImageView.image = self.images[indexPath.row];
    [cell setNeedsLayout];
    return cell;
}


@end
