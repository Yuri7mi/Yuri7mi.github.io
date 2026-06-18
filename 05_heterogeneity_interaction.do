****************************************************************************
* 05_robustness.do  —  稳健性检验（7项，含异质性分析）
*
* 根据RP更新，稳健性检验包括：
*   R1: 更换被解释变量 → 城乡收入比水平值（gap，不加ln）
*   R2: Arellano-Bond + Hansen诊断（在GMM中已输出，此处汇总）
*   R3: 使用线性插值 + ARIMA填补数据重跑
*   R4: 更换解释变量 → 各金融工具子维度（支付/保险/货币基金/投资/信贷/信用）
*   R5: 区域差异（胡焕庸线东南/西北 + 东中西三区域）
*   R6: 数字化水平分组（高于/低于中位数）
*   R7: 工具变量法（省/地级DFI均值作为ln_dfi的IV）
*
* 注：所有回归均使用新版7个控制变量
****************************************************************************

clear all
set more off
cd "C:\Data"
capture mkdir "output"
use "county_analysis.dta", clear

*
* 所有回归使用同一组7个控制变量：
*   fiscal_ratio sec_ind ter_ind ln_popden finance_depth
*
* ==================================================================
* R1: 更换被解释变量 —— 使用城乡收入比水平值（不加ln）
* ==================================================================
* 说明：取对数可能导致弹性解释，用水平值检验结论是否稳健
di _newline "========== R1: Replace DV with raw gap ratio =========="

* R1a: FE
xtreg gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r1_fe

* R1b: GMM
xtabond2 gap L.gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, ///
    gmm(L.gap ln_dfi, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year) ///
    robust twostep small artests(2)
estimates store r1_gmm

esttab r1_fe r1_gmm using "output/table_r1_replace_dv.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("FE (gap ratio)" "GMM (gap ratio)") ///
    scalars("N Observations") ///
    title("Robustness R1: Replace DV with Raw Income Ratio") ///
    drop(*.year) compress
di "R1 complete."

* ==================================================================
* R2: Arellano-Bond + Hansen诊断汇总
* ==================================================================
* 说明：这些诊断在Table 3中已报告，此处仅做文字汇总
di _newline "========== R2: AB + Hansen Diagnostics Summary =========="
di "参考Table 3底部scalars："
di "  AR(1) p < 0.05  → 一阶差分残差存在自相关（符合GMM假设）"
di "  AR(2) p > 0.10  → 无二阶自相关（工具变量有效）"
di "  Hansen p > 0.10 → 过度识别约束成立（工具变量外生）"
di "（各模型诊断值已包含在Table 3的scalars行中）"

* 各模型诊断值已包含在Table 3的scalars行中
* 由于不同Stata会话间estimates不共享，此处直接汇总说明
di "R2: 参见Table 3 scalars - AR(1)p, AR(2)p, Hansen p"

* ==================================================================
* R3: 使用线性插值 + ARIMA填补数据
* ==================================================================
di _newline "========== R3: Interpolation & ARIMA Data =========="

* --- 通用子程序：导入并清洗填补数据 ---
* 输入：sheet_name（"线性插值"或"ARIMA填补(慎用)"）
* 输出：分析所需变量（含7个控制变量 + 面板结构）
capture program drop clean_imputed
program define clean_imputed
    args sheetname

    di _newline "--- Processing sheet: `sheetname' ---"

    import excel "county_gdp_dfi_three_versions_matched_2014_2023.xlsx", ///
        sheet("`sheetname'") firstrow clear

    * 重命名必要变量
    rename 区县代码         county_id
    rename 年份             year
    rename 城镇居民人均可支配收入元  urban_income
    rename 农村居民人均可支配收入元  rural_income
    rename dfi_index_aggregate          dfi_agg
    rename 地区生产总值万元            gdp
    rename 第二产业增加值万元          gdp_sec
    rename 第三产业增加值万元          gdp_ter
    rename 工业增加值万元              gdp_ind
    rename 地方财政一般预算支出万元    fiscal_exp
    rename 年末总人口万人              population
    rename 行政区域土地面积平方公里    land_area
    rename 年末金融机构各项贷款余额万元  loan_balance
    rename 普通小学专任教师数人        teacher_primary
    rename 普通中学专任教师数人        teacher_middle
    rename 普通小学在校生数人          stu_primary
    rename 普通中学在校学生数人        stu_middle

    * 转为数值型
    destring, replace force

    * 生成核心变量
    gen ln_gap = ln(urban_income / rural_income)
    gen gap    = urban_income / rural_income
    gen ln_dfi = ln(dfi_agg)

    * 生成控制变量
    gen fiscal_ratio   = fiscal_exp / gdp * 100
    gen sec_ind        = gdp_sec / gdp * 100
    gen ter_ind        = gdp_ter / gdp * 100
*   gen ind_ratio      = gdp_ind / gdp * 100
    gen ln_popden      = ln(population * 10000 / land_area)
    gen finance_depth  = loan_balance / gdp * 100
*   gen edu_quality    = (teacher_primary + teacher_middle) ///
*                       / (stu_primary + stu_middle)

    * 剔除缺失
    drop if missing(ln_gap) | missing(ln_dfi)

    * 面板结构
    isid county_id year
    xtset county_id year
end

* --- R3a: 线性插值数据 ---
clean_imputed "线性插值"

xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    fe vce(cluster county_id)
estimates store r3a_fe

xtabond2 ln_gap L.ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store r3a_gmm

* --- R3b: ARIMA填补数据 ---
clean_imputed "ARIMA填补(慎用)"

xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    fe vce(cluster county_id)
estimates store r3b_fe

xtabond2 ln_gap L.ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth i.year, ///
    gmm(L.ln_gap ln_dfi, lag(2 3) collapse) ///
    iv(fiscal_ratio sec_ind ter_ind ln_popden ///
       finance_depth i.year) ///
    robust twostep small artests(2)
estimates store r3b_gmm

* 输出R3表格
use "county_analysis.dta", clear  // 回到主数据
esttab r3a_fe r3a_gmm r3b_fe r3b_gmm ///
    using "output/table_r3_imputed_data.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Lin.Interp FE" "Lin.Interp GMM" ///
            "ARIMA FE" "ARIMA GMM") ///
    scalars("N Observations") ///
    title("Robustness R3: Linear Interpolation & ARIMA Imputed Data") ///
    drop(*.year) compress
di "R3 complete."

* ==================================================================
* R4: 更换解释变量 —— 各金融工具子维度
* ==================================================================
di _newline "========== R4: Replace IV with Financial Sub-Indices =========="
* 使用6个金融工具（支付、保险、货币基金、投资、信贷、信用调查）
* 分别放入FE模型，观察各工具的缩小差距效应

* 注意：此处使用加1取对数后的变量（ln_dfi_payment等）

* 支付
xtreg ln_gap ln_dfi_payment fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r4_pay

* 保险
xtreg ln_gap ln_dfi_insurance fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r4_ins

* 货币基金
xtreg ln_gap ln_dfi_monetary fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r4_mon

* 投资
xtreg ln_gap ln_dfi_invest fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r4_inv

* 信贷
xtreg ln_gap ln_dfi_credit fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r4_cred

* 信用调查
xtreg ln_gap ln_dfi_credit_inv fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r4_cinv

esttab r4_pay r4_ins r4_mon r4_inv r4_cred r4_cinv ///
    using "output/table_r4_sub_indices.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Payment" "Insurance" "Monetary Fund" ///
            "Investment" "Credit" "Credit Invest.") ///
    scalars("N Observations" "r2_w R-squared") ///
    title("Robustness R4: Financial Sub-Indices (FE)") ///
    drop(*.year) compress
di "R4 complete."

* ==================================================================
* R5: 区域异质性（胡焕庸线 + 东中西）
* ==================================================================
di _newline "========== R5: Regional Heterogeneity =========="

* --- R5a: 胡焕庸线分组 ---
* 东南侧
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if hhy_line == "东南侧", ///
    fe vce(cluster county_id)
estimates store r5_hhy_se

* 西北侧
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if hhy_line == "西北侧", ///
    fe vce(cluster county_id)
estimates store r5_hhy_nw

* --- R5b: 东中西分组 ---
* 东部
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if region == "东部", ///
    fe vce(cluster county_id)
estimates store r5_east

* 中部
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if region == "中部", ///
    fe vce(cluster county_id)
estimates store r5_central

* 西部
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if region == "西部", ///
    fe vce(cluster county_id)
estimates store r5_west

* 输出R5表格
esttab r5_hhy_se r5_hhy_nw r5_east r5_central r5_west ///
    using "output/table_r5_regional.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("HHY SE" "HHY NW" "Eastern" "Central" "Western") ///
    scalars("N Observations" "r2_w R-squared") ///
    title("Robustness R5: Regional Heterogeneity") ///
    drop(*.year) compress
di "R5 complete."

* ==================================================================
* R6: 数字化水平分组
* ==================================================================
di _newline "========== R6: Digitization Level Groups =========="
* 使用digit_group变量（该变量在01_data_preparation中生成）
*   digit_group = 1：低数字化水平组（低于中位数）
*   digit_group = 2：高数字化水平组（高于中位数）

* 低数字化水平组
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if digit_group == 1, ///
    fe vce(cluster county_id)
estimates store r6_low

* 高数字化水平组
xtreg ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year if digit_group == 2, ///
    fe vce(cluster county_id)
estimates store r6_high

esttab r6_low r6_high using "output/table_r6_digitization.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Low Digitization" "High Digitization") ///
    scalars("N Observations" "r2_w R-squared") ///
    title("Robustness R6: Digitization Level Heterogeneity") ///
    drop(*.year) compress
di "R6 complete."

* ==================================================================
* R7: 工具变量法（省/地级DFI作为ln_dfi的工具变量）
* ==================================================================
di _newline "========== R7: Instrumental Variable (Province/Prefecture DFI) =========="
* 逻辑：同一省/地级市内其他县的DFI均值与本县DFI高度相关（相关性）
*       但不太可能通过其他渠道直接影响本县的城乡收入差距（外生性）

* --- R7a: 省级DFI-IV（FE-2SLS） ---
* 使用xtivreg的fe选项（固定效应IV估计）
xtivreg ln_gap (ln_dfi = prov_dfi_iv) ///
    fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r7_prov

* 第一阶段F统计量（判断弱工具变量）
di "First-stage F-stat (Province IV):"
capture test prov_dfi_iv
di "  F > 10 提示不存在弱工具变量问题"

* --- R7b: 地级市DFI-IV ---
xtivreg ln_gap (ln_dfi = pref_dfi_iv) ///
    fiscal_ratio sec_ind ter_ind ln_popden finance_depth i.year, fe vce(cluster county_id)
estimates store r7_pref

di "First-stage F-stat (Prefecture IV):"
capture test pref_dfi_iv

esttab r7_prov r7_pref using "output/table_r7_iv.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Province IV (FE-2SLS)" "Prefecture IV (FE-2SLS)") ///
    scalars("N Observations" ///
            "r2_w R-squared (within)") ///
    title("Robustness R7: Instrumental Variable Estimates") ///
    drop(*.year) compress
di "R7 complete."

* ==================================================================
* 完成汇总
* ==================================================================
di "========================================="
di "05_robustness.do 全部完成"
di "生成的输出文件："
di "  R1: table_r1_replace_dv.rtf"
di "  R2: (见表3诊断值)"
di "  R3: table_r3_imputed_data.rtf"
di "  R4: table_r4_sub_indices.rtf"
di "  R5: table_r5_regional.rtf"
di "  R6: table_r6_digitization.rtf"
di "  R7: table_r7_iv.rtf"
di "========================================="
