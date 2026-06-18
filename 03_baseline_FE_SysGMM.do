****************************************************************************
* 03_empirical_strategy.do  —  三大基准模型（RP新版规格）
*
* 根据RP要求，本文的Empirical Strategy包含三组模型：
*   Part A — 双向固定效应模型（Two-way FE, 基准）
*   Part B — 系统GMM（System GMM, 核心模型）
*   Part C — 交互项模型（Interaction, DFI调节效应）
*
* 控制变量全部更新为7个比率/密度类变量
****************************************************************************

clear all
set more off
cd "C:\Data"
capture mkdir "output"
use "county_analysis.dta", clear

* ==================================================================
* Part A: 双向固定效应（Two-way FE）
* ==================================================================
* 模型逻辑：
*   xtreg, fe = 县固定效应（控制不随时间变化的县特征）
*   i.year     = 年份固定效应（控制共同时间趋势）
*   vce(cluster county_id) = 县层面聚类稳健标准误
*
* 控制变量按经济含义分组逐步加入：

* --- (1) 仅DFI + 年份FE ---
xtreg ln_gap ln_dfi i.year, fe vce(cluster county_id)
estimates store fe1

* --- (2) + 财政规模 + 产业结构（第二、三产业占比） ---
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    i.year, fe vce(cluster county_id)
estimates store fe2

* --- (3) + 工业占比 + 人口密度 ---
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden i.year, fe vce(cluster county_id)
estimates store fe3

* --- (4) 全部7个控制变量（完整规格） ---
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    fe vce(cluster county_id)
estimates store fe4

* 导出Table 2
esttab fe1 fe2 fe3 fe4 using "output/table2_fe_results.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("N Observations" "r2_w R-squared (within)") ///
    mtitles("(1) No controls" "(2) +Fiscal+Structure" ///
            "(3) +Industry+Pop" "(4) Full controls") ///
    title("Table 2: Two-way Fixed Effects Estimates") ///
    drop(*.year) compress

di "=== Part A (FE) complete ==="

* ==================================================================
* Part B: 系统GMM（System GMM）
* ==================================================================
* 解决两大问题：
*   ① 收入差距的持续性 → 动态面板（滞后被解释变量）
*   ② DFI与收入差距的反向因果 → 内部工具变量（滞后项）
*
* 诊断标准：
*   AR(1) p < 0.05 （一阶差分残差存在自相关，符合预期）
*   AR(2) p > 0.10 （二阶无自相关，工具变量有效）
*   Hansen  p > 0.10 （过度识别约束成立）
*   工具变量数 < 县数（避免过多IV偏误）

* --- (5) 基本GMM（不限制IV数量，参考规格） ---
xtabond2 ln_gap L.ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi, lag(2 4)) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store gmm1

* --- (6) 折叠GMM（collapse，减少IV数量，主规格） ---
xtabond2 ln_gap L.ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store gmm2

* --- (7) 更严格滞后阶数（lag(3 4)，进一步限制IV数量） ---
xtabond2 ln_gap L.ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi, lag(3 4) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store gmm3

* 导出Table 3
esttab gmm1 gmm2 gmm3 using "output/table3_gmm_results.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("N Observations" ///
            "ar1p AR(1) p-value" ///
            "ar2p AR(2) p-value" ///
            "hansenp Hansen J p-value" ///
            "j J-statistic" ///
            "N_g Number of instruments") ///
    mtitles("(5) GMM basic" "(6) GMM collapsed" "(7) GMM strict lag") ///
    title("Table 3: System GMM Estimates") ///
    drop(*.year) compress

* 打印诊断说明
di _newline "====== GMM DIAGNOSTICS ======"
di "AR(1): should be < 0.05 → 拒绝无自相关原假设"
di "AR(2): should be > 0.10 → 不存在二阶自相关"
di "Hansen: should be > 0.10 → 工具变量外生"
di "N_instruments < N_counties → 避免过多IV"

* 提取并显示GMM2（主规格）的诊断值
estimates restore gmm2
local ar1p = e(ar1p)
local ar2p = e(ar2p)
local hansenp = e(hansenp)
local j = e(j)
local N_g = e(N_g)
di _newline "GMM2 Diagnostics:"
di "  AR(1) p = `ar1p'"
di "  AR(2) p = `ar2p'"
di "  Hansen p = `hansenp'"
di "  J-stat  = `j'"
di "  # instruments ≈ `N_g'"

di "=== Part B (GMM) complete ==="

* ==================================================================
* Part C: DFI调节效应模型（Interaction Model）
* ==================================================================
* 理论：DFI能否弱化"经济发展水平 → 收入差距扩大"的关系？
* 方法：ln_dfi与ln_gdp_pc的交互项（中心化后）
* （注：ln_gdp_pc不在常规控制变量中，此处作为调节变量单独纳入）

* --- 中心化处理 ---
summarize ln_dfi
gen ln_dfi_c = ln_dfi - r(mean)
label var ln_dfi_c "DFI (centered)"

summarize ln_gdp_pc
gen ln_gdp_pc_c = ln_gdp_pc - r(mean)
label var ln_gdp_pc_c "Log GDP per capita (centered)"

* --- 交互项FE模型 ---
* c.ln_dfi_c##c.ln_gdp_pc_c 等价于 ln_dfi_c + ln_gdp_pc_c + ln_dfi_c × ln_gdp_pc_c
xtreg ln_gap c.ln_dfi_c##c.ln_gdp_pc_c ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, ///
    fe vce(cluster county_id)
estimates store inter_fe

* 计算边际效应：ln_gdp_pc_c = -2, -1, 0, 1, 2 处DFI的斜率
margins, dydx(ln_dfi_c) at(ln_gdp_pc_c = (-2 -1 0 1 2))

* --- 边际效应图 ---
marginsplot, ///
    title("Marginal Effect of DFI on Income Gap") ///
    ytitle("Marginal Effect of DFI") ///
    xtitle("Log GDP per capita (deviation from mean)") ///
    graphregion(color(white))
graph export "output/fig7_marginal_effect.png", replace width(1200)

* 导出Table 4
esttab inter_fe using "output/table4_interaction.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("N Observations" "r2_w R-squared (within)") ///
    mtitles("Interaction FE") ///
    title("Table 4: Interaction Effect of DFI and Economic Development") ///
    drop(*.year) compress

di "=== Part C (Interaction) complete ==="

* ==================================================================
* 完成
* ==================================================================
di "========================================="
di "03_empirical_strategy.do 完成"
di "Table 2 (FE) → output/table2_fe_results.rtf"
di "Table 3 (GMM) → output/table3_gmm_results.rtf"
di "Table 4 (Interaction) → output/table4_interaction.rtf"
di "Fig 7 (Marginal effects) → output/fig7_marginal_effect.png"
di "========================================="
