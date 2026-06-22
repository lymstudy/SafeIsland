Makefile
快速脚本文件 使用：make
组成部分：变量 目标 依赖 命令

默认执行第一个目标
| 选项                   | 作用                                                  |
| -------------------- | --------------------------------------------------- |
| `vcs`                | 运行 VCS（Verilog 编译仿真器）。                              |
| `-R`                 | 编译后立即运行仿真（等价于 `./simv`）。                            |
| `-ntb_opts uvm-1.1`  | 启用 UVM 1.1 版本，用于 UVM 体系结构的验证环境。                     |
| `-full64`            | 使用 64 位模式，提高大规模仿真的性能。                               |
| `-fsdb`              | 使仿真支持 `.fsdb` 波形格式（常用于 Verdi）。                      |
| `+define+FSDB`       | 定义 FSDB 宏，用于条件编译（例如 `ifdef FSDB ... endif`）。        |
| `-sverilog`          | 支持 SystemVerilog 语法，扩展 Verilog 功能。                  |
| `-debug_acc+all`     | 启用所有信号的调试访问权限（方便 Verdi 调试）。                         |
| `+timescale+1ns/1ps` | 设置仿真时间单位（1ns，精度 1ps）。                               |
| `-f filelist.f`      | 从 `filelist.f` 文件读取所有待编译的 Verilog/SystemVerilog 文件。 |
| `-l com.log`         | 将编译和仿真日志写入 `com.log`，方便调试错误。                        |
![alt text](image.png)

filelist.f 设计与tb文件
+incdir+

![alt text](image-1.png)


OPT= -R -full64 +v2k -fsdb +define+FSDB -sverilog -debug_all -lca -kdb -timescale=1ns/1ps -f 0.filelist.f +cli +3

vcs: clean comp_quick

clean:
	rm -rf simv*
	rm -rf csrc
	rm -rf verdiLog
	rm -f novas* tb_sas.* ucli.key vc_hdrs.h
	rm -rf *.fsdb.*

verdi:
	verdi -dbdir simv.daidir -ssf waveform.fsdb -preTitle vcs_initial_clean -sv &

comp_quick:
	vcs $(OPT) -l tb_log.log
	./simv