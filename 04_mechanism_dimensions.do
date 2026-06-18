****************************************************************************
* 04_mechanism_dimensions.do  —  机制分析（H2城乡分解 + H3维度分解）
*
* H2：DFI是通过提高城镇收入还是农村收入来缩小差距？
*   → 将ln_gap拆解为ln_urban和ln_rural分别作为被解释变量
*   → 如果DFI对ln_rural的促进效应 > 对ln_urban的促进效应 → 支持"惠农"假说
*
* H3：DFI的哪个维度对缩小差距贡献最大？
*   → 覆盖广度（ln_dfi_br）、使用深度（ln_dfi_dep）、数字化程度（ln_dfi_dig）
*   → 再进一步拆解子维度（支付、保险、货币基金、投资、信贷、信用调查）
*
* 所有模型使用新版7个控制变量
****************************************************************************

clear all
set more off
cd "C:\Data"
capture mkdir "output"
use "county_analysis.dta", clear

* --- 生成城乡收入对数变量（H2被解释变量） ---
gen ln_urban = ln(urban_income)
gen ln_rural = ln(rural_income)
label var ln_urban "Log Urban Income"
label var ln_rural "Log Rural Income"

* ==================================================================
* H2: 城乡收入分解
* ==================================================================
* 逻辑：分别以ln_urban和ln_rural为被解释变量，对比ln_dfi系数

* --- 2a: FE —— DFI对城镇收入的影响 ---
* 控制变量：fiscal_ratio sec_ind ter_ind ln_popden finance_depth
xtreg ln_urban ln_dfi fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, fe vce(cluster county_id)
estimates store urban_fe

* --- 2b: FE —— DFI对农村收入的影响 ---
xtreg ln_rural ln_dfi fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, fe vce(cluster county_id)
estimates store rural_fe

* 对比：若rural的ln_dfi系数 > urban的ln_dfi系数 → 支持"惠农"假说
di _newline "=== H2: Coefficient comparison ==="

* --- 2c: GMM —— 城镇收入（动态面板） ---
xtabond2 ln_urban L.ln_urban ln_dfi ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, ///
    gmm(L.ln_urban ln_dfi, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store urban_gmm

* --- 2d: GMM —— 农村收入 ---
xtabond2 ln_rural L.ln_rural ln_dfi ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, ///
    gmm(L.ln_rural ln_dfi, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store rural_gmm

* 输出H2结果（Table 5）
esttab urban_fe rural_fe urban_gmm rural_gmm ///
    using "output/table5_urban_rural.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Urban FE" "Rural FE" "Urban GMM" "Rural GMM") ///
    title("Table 5: Urban vs. Rural Income Effects") ///
    drop(*.year) compress

di "=== H2 (Urban/Rural Decomposition) complete ==="

* ==================================================================
* H3: DFI维度分解
* ==================================================================
* 将DFI总指数拆解为三个主维度+细分子维度
* 预期：使用深度 > 覆盖广度 > 数字化程度（以缩小差距效应论）

* --- 3a: 三个主维度同时放入FE ---
xtreg ln_gap ln_dfi_br ln_dfi_dep ln_dfi_dig ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, fe vce(cluster county_id)
estimates store dim_fe

* 联合显著性检验（三个维度系数是否同时为零）
test ln_dfi_br ln_dfi_dep ln_dfi_dig

* --- 3b: 三个主维度放入GMM ---
xtabond2 ln_gap L.ln_gap ln_dfi_br ln_dfi_dep ln_dfi_dig ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi_br ln_dfi_dep ln_dfi_dig, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store dim_gmm

* --- 3c: 细分子维度FE ---
* 将"使用深度"拆为支付、保险、投资、货币基金、信贷 + 覆盖广度 + 数字化程度
xtreg ln_gap ln_dfi_br ln_dfi_payment ln_dfi_insurance ///
    ln_dfi_monetary ln_dfi_invest ln_dfi_credit ln_dfi_dig ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, fe vce(cluster county_id)
estimates store subdim_fe

* --- 3d: 细分子维度GMM（精选子维度避免IV过多） ---
* 注意：GMM中放入过多内生子维度可能导致工具变量爆炸
* 此处仅保留核心子维度：支付、保险、信贷、数字化程度
xtabond2 ln_gap L.ln_gap ln_dfi_br ln_dfi_payment ///
    ln_dfi_insurance ln_dfi_credit ln_dfi_dig ///
    fiscal_ratio sec_ind ter_ind ln_popden ///
    finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi_br ln_dfi_payment, lag(2 3) collapse) ///
    iv(ln_dfi_insurance ln_dfi_credit ln_dfi_dig ///
       fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store subdim_gmm

* 输出H3结果（Table 6）
esttab dim_fe dim_gmm subdim_fe subdim_gmm ///
    using "output/table6_dimensions.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("3-dim FE" "3-dim GMM" "Sub-dim FE" "Sub-dim GMM") ///
    title("Table 6: DFI Dimension Decomposition") ///
    drop(*.year) compress

di "=== H3 (Dimension Decomposition) complete ==="

di "========================================="
di "04_mechanism_dimensions.do 完成"
di "Table 5 (urban/rural) - output/table5_urban_rural.rtf"
di "Table 6 (dimensions) - output/table6_dimensions.rtf"
di "========================================="
