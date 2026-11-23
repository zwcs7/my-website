# 问题四离线运行参数

本目录的 `problem4_solver_settings.json` 是提交版问题四离线复核所需的参数文件。

在 MATLAB R2024b 中先把当前文件夹切换到包内 `code`，再运行：

```matlab
config = jsondecode(fileread(fullfile('..','data','run_config','problem4_solver_settings.json')));
result = problem4("offline",config);
```

该离线入口只依赖提交包内的 `code/problem4.m` 和本参数文件，会在 `code/运行结果` 下新建结果目录，不依赖原电脑的绝对路径、其他工程目录或联网模拟器。

根目录 `正式模拟/问题4` 保存三次已完成正式测试的原始 `.jlog`。正式测试机会已经使用完毕；实时身份、端口、当局案例和 GUI 确认信息不是离线复核资源，也不应据此重跑正式测试。
