****************************************************************************
* 02_descriptive_analysis.do  —  描述性统计与可视化（新版控制变量）
*
* 功能：
*   Table 1：全部变量的描述性统计
*   Fig 1-3：城乡收入比、DFI、双轴趋势图
*   Fig 4：  DFI-收入差距散点图
*   Fig 5-6：区域（东/中/西）与胡焕庸线分组趋势
*   相关系数矩阵
****************************************************************************

clear all                        // 清除内存
set more off                     // 关闭more暂停
cd "C:\Data"                     // 工作目录
capture mkdir "output"           // 创建输出文件夹
use "county_analysis.dta", clear // 载入分析数据集

* ===================================================================
* Table 1: 描述性统计
* ===================================================================
* 报告：样本量、均值、标准差、最小值、最大值
* 涵盖：被解释变量、解释变量、7个新控制变量、子维度
estpost summarize ln_gap gap ln_dfi ln_dfi_br ln_dfi_dep ln_dfi_dig ///
    fiscal_ratio sec_ind ter_ind ln_popden finance_depth ///
    urban_income rural_income, detail

esttab using "output/table1_descriptives.rtf", replace ///
    cells("count(fmt(%9.0f)) mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3))") ///
    title("Table 1: Summary Statistics") ///
    nomtitle nonumber

di "=== Table 1 exported ==="

* ===================================================================
* Fig 1-3: 时间趋势图（按年县级简单平均）
* ===================================================================
preserve
* 折叠为逐年均值
collapse (mean) gap ln_gap urban_income rural_income dfi_agg ///
    [aw = 1], by(year)

* --- Fig 1: 城乡收入比趋势 ---
twoway (line gap year, lcolor(navy) lwidth(medthick)), ///
    title("Urban-Rural Income Ratio (2014-2023)") ///
    ytitle("Urban / Rural Income Ratio") xtitle("Year") ///
    ylabel(, format(%9.2f)) ///
    note("Data: County-level panel, unweighted county average") ///
    graphregion(color(white))
graph export "output/fig1_gap_trend.png", replace width(1200)

* --- Fig 2: DFI指数趋势 ---
twoway (line dfi_agg year, lcolor(cranberry) lwidth(medthick)), ///
    title("Digital Financial Inclusion Index (2014-2023)") ///
    ytitle("PKU-DFIIC Aggregate Index") xtitle("Year") ///
    note("Data: County-level panel, unweighted county average") ///
    graphregion(color(white))
graph export "output/fig2_dfi_trend.png", replace width(1200)

* --- Fig 3: 双轴组合图（收入差距左侧Y轴 + DFI右侧Y轴） ---
twoway (line gap year, lcolor(navy)) ///
       (line dfi_agg year, lcolor(cranberry) yaxis(2)), ///
    title("Income Gap and DFI Over Time") ///
    ytitle("Urban/Rural Ratio", axis(1)) ///
    ytitle("DFI Index", axis(2)) xtitle("Year") ///
    legend(order(1 "Income Gap" 2 "DFI Index")) ///
    note("Data: County-level panel, unweighted county average") ///
    graphregion(color(white))
graph export "output/fig3_gap_dfi_trend.png", replace width(1400)
restore

* ===================================================================
* Fig 4: DFI vs 收入差距散点图（含拟合线）
* ===================================================================
preserve
collapse (mean) ln_gap ln_dfi, by(year)

twoway (scatter ln_gap ln_dfi, mcolor(navy) msize(medium)) ///
       (lfit ln_gap ln_dfi, lcolor(cranberry)), ///
    title("DFI vs Income Gap (2014-2023)") ///
    ytitle("Log Income Gap") xtitle("Log DFI Index") ///
    legend(order(1 "Annual average" 2 "Fitted line")) ///
    note("Data: County-level panel, unweighted county average") ///
    graphregion(color(white))
graph export "output/fig4_scatter_dfi_gap.png", replace width(1200)
restore

* ===================================================================
* Fig 5-6: 分组趋势图
* ===================================================================

* --- Fig 5: 东/中/西部收入差距趋势 ---
bysort region year: egen region_gap = mean(gap)

preserve
collapse (mean) region_gap, by(region year)

twoway (line region_gap year if region == "东部", lcolor(blue)) ///
       (line region_gap year if region == "中部", lcolor(red)) ///
       (line region_gap year if region == "西部", lcolor(green)), ///
    title("Income Gap by Region") ///
    ytitle("Urban/Rural Income Ratio") xtitle("Year") ///
    legend(order(1 "Eastern" 2 "Central" 3 "Western")) ///
    graphregion(color(white))
graph export "output/fig5_gap_by_region.png", replace width(1200)
restore

* --- Fig 6: 胡焕庸线分组趋势 ---
bysort hhy_line year: egen hhy_gap = mean(gap)

preserve
collapse (mean) hhy_gap, by(hhy_line year)

twoway (line hhy_gap year if hhy_line == "东南侧", lcolor(blue)) ///
       (line hhy_gap year if hhy_line == "西北侧", lcolor(red)), ///
    title("Income Gap by Hu Huanyong Line") ///
    ytitle("Urban/Rural Income Ratio") xtitle("Year") ///
    legend(order(1 "South-East" 2 "North-West")) ///
    graphregion(color(white))
graph export "output/fig6_gap_by_hhy.png", replace width(1200)
restore

* ===================================================================
* 相关系数矩阵（核心变量）
* ===================================================================
pwcorr ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth, star(0.01)

di "========================================="
di "02_descriptive_analysis.do 完成"
di "Tables and figures saved to output/ folder."
di "========================================="
