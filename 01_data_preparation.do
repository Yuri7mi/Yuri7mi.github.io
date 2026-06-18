****************************************************************************
* 01_data_preparation.do  —  数据导入与清洗（新版控制变量）
*
* 根据RP修改要求：
*   DV不变：ln_gap（城乡收入对数比）
*   IV不变：ln_dfi（DFI总指数对数）+ 子维度
*   控制变量改为7个比率/密度/比率类变量（详见Step 4）
*   新增稳健性检验变量：省/地级leave-one-out DFI均值（工具变量法用）
*   新增变量：教师数（用于构造师生比）、数字化水平分组
****************************************************************************

clear all                        // 清除Stata内存
set more off                     // 关闭more提示（批处理模式必需）
cd "C:\Data"                     // 设置工作目录

* ===================================================================
* Step 1: 从Excel导入原始数据
* ===================================================================
import excel "county_gdp_dfi_three_versions_matched_2014_2023.xlsx", ///
    sheet("原始数据") firstrow clear
* firstrow: 将Excel首行作为变量名（括号自动移除）
* 例: "城镇居民人均可支配收入(元)" → "城镇居民人均可支配收入元"

* ===================================================================
* Step 2: 字符串→数值型转换
* ===================================================================
destring, replace ignore(",")
* ignore(",")处理含逗号的数字如"1,234"→1234；纯文本变量自动跳过

* ===================================================================
* Step 3: 重命名（中文→英文）
* ===================================================================

* --- 标识变量 ---
rename 区县代码              county_id         // 县唯一编码
rename 年份                  year
rename 区县                  county_name       // 县名称
rename 所属地域              region            // 东/中/西部
rename 省份                  province
rename 城市                  prefecture_name   // 地级市名称（用于IV分组）
rename 胡焕庸线              hhy_line          // 东南侧/西北侧

* --- 收入 ---
rename 城镇居民人均可支配收入元  urban_income
rename 农村居民人均可支配收入元  rural_income

* --- 经济总量 ---
rename 地区生产总值万元          gdp
rename 第一产业增加值万元        gdp_pri
rename 第二产业增加值万元        gdp_sec
rename 第三产业增加值万元        gdp_ter
rename 人均地区生产总值元人      gdp_pc
rename 工业增加值万元            gdp_ind
rename 城镇单位在岗职工平均工资元 avg_wage
rename 农业增加值万元            gdp_agri
rename 牧业增加值万元            gdp_lvstk

* --- 财政 ---
rename 地方财政一般预算收入万元  fiscal_rev
rename 地方财政一般预算支出万元  fiscal_exp
rename 各项税收万元              tax

* --- 人口与社会 ---
rename 年末总人口万人            population
rename 乡村人口万人              rural_pop
rename 乡村从业人员数人          rural_emp
rename 普通中学在校学生数人      stu_middle
rename 普通小学在校生数人        stu_primary
rename 医院卫生院床位数床        hospital_beds
rename 医院和卫生院卫生人员数_卫生技术人员人 health_tech
rename 医院和卫生院卫生人员数_执业医师人 health_doc
rename 年末总户数户              n_household
rename 乡村户数户                rural_household

* --- 教师数量（新增——用于师生比） ---
rename 普通小学专任教师数人      teacher_primary   // 小学专任教师数
rename 普通中学专任教师数人      teacher_middle    // 中学专任教师数

* --- 土地与农业 ---
rename 行政区域土地面积平方公里  land_area
rename 农作物总播种面积千公顷    crop_area
rename 常用耕地面积公顷          farmland
rename 粮食总产量吨              grain_output
rename 农林牧渔业总产值万元      agri_output
rename 农用机械总动力千万瓦      agri_machine

* --- 金融（核心：贷款余额用于finance_depth） ---
rename 年末金融机构各项贷款余额万元  loan_balance

* --- 其他经济 ---
rename 城乡居民储蓄存款余额万元  savings
rename 社会消费品零售总额万元    retail_sales
rename 全社会固定资产投资万元    fix_invest
rename 城镇固定资产投资完成额万元 urban_fix_invest
rename 规模以上工业企业数个      n_industrial
rename 规模以上工业总产值万元    industrial_output
rename 房地产开发投资亿元        real_estate_inv
rename 普通中学学校数个          n_middleschool
rename 普通小学学校数个          n_primaryschool
rename 移动电话用户数户          mobile_users
rename 宽带接入用户数户          broadband_users
rename 出口额美元                export_usd
rename 实际利用外资金额美元      fdi_usd
rename 各种社会福利收养性单位床位数床 welfare_beds
rename 全社会用电量万千瓦时      electricity

* --- DFI总指数 + 三个主维度 ---
rename dfi_index_aggregate          dfi_agg
rename dfi_coverage_breadth         dfi_breadth
rename dfi_usage_depth              dfi_depth
rename dfi_digitization_level       dfi_digit

* --- DFI细分子维度（稳健性检验#4：更换解释变量） ---
rename dfi_payment                  dfi_payment
rename dfi_insurance                dfi_insurance
rename dfi_monetary_fund            dfi_monetary
rename dfi_investment               dfi_invest
rename dfi_credit                   dfi_credit
rename dfi_credit_investigation     dfi_credit_inv

* --- 省/地级代码（稳健性检验#7：工具变量） ---
rename dfi_prov_code                prov_code
rename dfi_prov_name                prov_name
rename dfi_pref_code                pref_code
rename dfi_pref_name                pref_name

* 确保标识变量为数值型
capture destring county_id, replace
capture destring year, replace

* 查看剩余字符串变量（确认无误）
ds, has(type string)
di "Remaining string vars: `r(varlist)'"
* 应只剩: county_name region province prefecture_name hhy_line prov_name pref_name 等

* ===================================================================
* Step 4: 删除关键缺失 + 生成分析变量
* ===================================================================

* --- 删除关键缺失 ---
drop if missing(urban_income) | missing(rural_income) | missing(dfi_agg)

* --- 4a: 被解释变量 ---
gen ln_gap = ln(urban_income / rural_income)   // 对数城乡收入比（核心DV）
gen gap    = urban_income / rural_income        // 水平值（用于图表 + 稳健性检验#1）
label var ln_gap "Log Urban-Rural Income Ratio"
label var gap    "Urban-Rural Income Ratio"

* --- 4b: 解释变量（DFI + 对数） ---
gen ln_dfi     = ln(dfi_agg)                      // 核心解释变量
gen ln_dfi_br  = ln(dfi_breadth)
gen ln_dfi_dep = ln(dfi_depth)
gen ln_dfi_dig = ln(dfi_digit)
label var ln_dfi "Log DFI Aggregate Index"

* --- 4c: DFI细分子维度对数（稳健性检验#4用） ---
* 加1取对数避免ln(0)问题（部分县在某些子维度上可能为0）
foreach var in dfi_payment dfi_insurance dfi_monetary ///
    dfi_invest dfi_credit dfi_credit_inv {
    count if `var' <= 0 & !missing(`var')
    gen ln_`var' = ln(`var' + 1)
}
label var ln_dfi_payment    "Log DFI Payment"
label var ln_dfi_insurance  "Log DFI Insurance"
label var ln_dfi_monetary   "Log DFI Monetary Fund"
label var ln_dfi_invest     "Log DFI Investment"
label var ln_dfi_credit     "Log DFI Credit"
label var ln_dfi_credit_inv "Log DFI Credit Investigation"

* --- 4d: 新版控制变量（7个） ---
* 原则：凡涉及GDP比率者，乘以100转为百分比，便于系数解读

* ① 地方财政支出规模 = 财政一般预算支出 / GDP × 100
count if fiscal_exp <= 0 & !missing(fiscal_exp) & fiscal_exp < .
di "Non-positive fiscal_exp: `r(N)'"
gen fiscal_ratio = fiscal_exp / gdp * 100
label var fiscal_ratio "Fiscal Exp. (% of GDP)"

* ② 第二产业增加值 / GDP × 100
gen sec_ind = gdp_sec / gdp * 100
label var sec_ind "Secondary Industry (% of GDP)"

* ③ 第三产业增加值 / GDP × 100
gen ter_ind = gdp_ter / gdp * 100
label var ter_ind "Tertiary Industry (% of GDP)"

* ④ 工业产值 / GDP × 100（暂不使用，因缺失过多）
* gen ind_ratio = gdp_ind / gdp * 100
* label var ind_ratio "Industrial Output (% of GDP)"

* ⑤ 人口密度（对数）—— 缺失面积做前向填补
*    逻辑：如果某年land_area缺失，用同县最近有记录年份的面积代替
sort county_id year
bys county_id (year): replace land_area = land_area[_n-1] ///
    if missing(land_area) & _n > 1
*    仍有缺失的，用该县非缺失均值填补
bys county_id: egen land_fill = mean(land_area)
replace land_area = land_fill if missing(land_area)
drop land_fill
*    人口密度 = 总人口(万人 → 人) / 面积(km²)
gen ln_popden = ln(population * 10000 / land_area)
label var ln_popden "Log Population Density"

* ⑥ 金融发展水平 = 年末金融机构贷款余额 / GDP × 100
gen finance_depth = loan_balance / gdp * 100
label var finance_depth "Loan Balance (% of GDP)"

* ⑦ 基础教育水平 = (小学教师+中学教师) / (小学生+中学生)（暂不使用，因缺失过多）
* gen edu_quality = (teacher_primary + teacher_middle) ///
*    / (stu_primary + stu_middle)
* label var edu_quality "Teacher-Student Ratio"

* 保留旧版控制变量（备而不删）
gen ln_gdp_pc   = ln(gdp_pc)
gen ln_fiscal   = ln(fiscal_exp)
gen ln_fixinv   = ln(fix_invest)

* 报告新控制变量的缺失情况
di "Missing values check for new controls:"
foreach var of varlist fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth {
    quietly count if missing(`var')
    di "  `var': `r(N)' missing"
}

* ===================================================================
* Step 5: 省/地级DFI工具变量（leave-one-out均值）
* ===================================================================
* 用于稳健性检验#7：以地级市或省级DFI均值作为ln_dfi的工具变量
* leave-one-out = 排除本县后同组其他县的平均值
* → 相关性：同组内DFI高度相关
* → 外生性：其他县的DFI应不直接影响本县的城乡收入差距

* 地级市层面
bys pref_code year: egen pref_total = total(dfi_agg)
bys pref_code year: egen pref_n    = count(dfi_agg)
gen pref_dfi_iv = (pref_total - dfi_agg) / (pref_n - 1)
label var pref_dfi_iv "Prefecture DFI (leave-one-out)"

* 省级层面
bys prov_code year: egen prov_total = total(dfi_agg)
bys prov_code year: egen prov_n    = count(dfi_agg)
gen prov_dfi_iv = (prov_total - dfi_agg) / (prov_n - 1)
label var prov_dfi_iv "Province DFI (leave-one-out)"

di "=== IV Descriptive Stats ==="
summarize pref_dfi_iv prov_dfi_iv, detail

* ===================================================================
* Step 6: 面板结构 + 分组变量
* ===================================================================

encode region, gen(region_num)

* 唯一性检查
isid county_id year

* 声明面板
xtset county_id year

* 发展水平分组（按2014年人均GDP中位数）
bys county_id: egen gdp_base = mean(cond(year == 2014, gdp_pc, .))
xtile dev_group = gdp_base, nq(2)
label define dev_lbl 1 "Less Developed" 2 "More Developed"
label values dev_group dev_lbl

* 数字化水平分组（用于稳健性检验#6）
bys county_id: egen avg_digit = mean(dfi_digit)
xtile digit_group = avg_digit, nq(2)
label define digit_lbl 1 "Low Digitization" 2 "High Digitization"
label values digit_group digit_lbl

* ===================================================================
* Step 7: 压缩保存 + 快速检查
* ===================================================================

compress
save "county_analysis.dta", replace

describe
summarize ln_gap ln_dfi fiscal_ratio sec_ind ter_ind ///
    ln_popden finance_depth
tab year

di "========================================="
di "01_data_preparation.do 完成"
di "新增控制变量: fiscal_ratio sec_ind ter_ind"
di "  ln_popden (forward-fill), finance_depth"
di "新增IV变量: pref_dfi_iv prov_dfi_iv"
di "========================================="
