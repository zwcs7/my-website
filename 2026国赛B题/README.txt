2026 国赛 B 题 支撑材料

人工审核状态：问题一、问题二、问题三、问题四均已通过人工审核（队伍确认）。

运行环境：MATLAB R2024b（24.2）。

运行顺序：
1. 在 MATLAB 中将当前文件夹切换至 code。
2. 问题一：result = problem1; 或 result = problem1('verify');
3. 问题二：result = problem2; 运行自建默认场景并在 code 下生成新结果目录。
4. 问题三：result = problem3("offline"); 正式测试机会已全部使用，本包仅保留可读源码和离线复核入口。
5. 问题四：config = jsondecode(fileread(fullfile('..','data','run_config','problem4_solver_settings.json'))); result = problem4("offline",config); 正式测试机会已全部使用。
6. 全部图形：run(fullfile('plot','plot_all.m'));

目录清单：
README.txt - 本说明、MATLAB 环境、运行顺序和文件清单。
code/problem1.m 至 code/problem4.m - 四问求解源码；为符合提交命名要求，文件名、主函数名和必要的内部自调用名已统一改为 problem1 至 problem4，算法逻辑未改。
code/plot/plot_all.m - 加载 figures/fig1.png 至 fig23.png 的统一浏览绘图脚本。
code/solve_q1.m、q2_localization.m、q3_formal.m、q4_solver.m - 原始函数名源码副本，用于来源追溯；日常复核优先使用 problem1 至 problem4。
code/q4_cover_certificate.m、q4_verify_cover.m - 问题四连续覆盖证书的参数化辅助函数，需要由调用者传入测站或证书，不是无参数运行入口。
code/run_formal01.m 至 run_formal03.m - 已完成的三次问题三正式测试所用历史脚本；其一次性 receipt 和实时模拟器状态不属于离线提交资源，正式机会已用完，请勿重跑。
figures/fig1.png 至 figures/fig23.png - 论文实际使用10幅图，其余为补充验证图；论文图号、包内文件及原始来源见 figures/README.txt。fig18.png、fig20.png 已与论文3.11的终版图例同步。
data/official_problem - 官方 B 题题面及两个接口附件。
data/results - 论文图表、正式结果、构造配对、动作记录、费用复核、覆盖证书和审计自测的可读支撑文件；文件名以 q1、q2、q3、q4 开头。
data/run_config - 问题四采用方案的运行参数；problem4_solver_settings.json 与论文旧名 settings.json 内容相同。
data/reference_literature - 实际使用的公开论文原件。
data/national_standard - 自行查阅的标准和相关资料，含类型说明。
引用1模拟数据 - 问题四引用的模拟器演练日志；可读结果与独立复核见 data/results 中 q4_T2Z9 开头的文件。
正式模拟 - 问题三和问题四各三次正式模拟日志。
AI工具使用详情.pdf - AI 工具使用说明提交文件。
SHA256SUMS.txt - 本包文件完整性清单。

离线移植核查（2026-09-13，MATLAB R2024b）：问题一无参数运行成功且 verify 71/71；问题二默认 6 场景、75/75；问题三 offline 42 场景、89/89；问题四 offline 56 场景全部通过；统一浏览脚本成功载入 23 张图。

除根目录 AI工具使用详情.pdf 外，本包未额外收集 AI 使用记录。原始资料和完整追溯档保持原位且未改动。
