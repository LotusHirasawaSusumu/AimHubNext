-- core/i18n.lua
-- AimHubNext Internationalization Module
-- Mod Author: CookieLee

local i18n = {}

local languages = {
    en = {
        -- Header
        menu_title          = "Aim Hub Next",
        menu_subtitle       = "Made by @Rakamo82 | Aim Hub Next Mod by CookieLee",
        btn_close           = "X",
        btn_minimize        = "—",
        btn_restore         = "+",

        -- Sidebar
        label_active        = "● Active",
        label_shortcuts     = "SHORTCUTS",
        shortcut_template   = "[%s] Aim (%s): %s\n[RShift] Minimize\nRage: %s | Silent: %s",
        shortcut_on         = "ON",
        shortcut_off        = "OFF",
        btn_system_status   = "SYSTEM WORKING",

        -- Search
        search_placeholder  = "Search features...",

        -- Tab names
        tab_aimlock         = "Aim Lock",
        tab_rage            = "Rage",
        tab_visuals         = "Visuals / ESP",
        tab_logs            = "System Logs",
        tab_customization   = "Customization",
        tab_settings        = "Settings",

        -- Aim Lock tab
        aim_master_title    = "System Master",
        aim_master_desc     = "Master toggle for all systems",
        aim_master_sub      = "Enables/disables entire engine.",

        aim_wallcheck_title = "Wall Check",
        aim_wallcheck_desc  = "Skip targets behind walls (uses Raycast)",
        aim_wallcheck_sub   = "Improved raycast with exclude filters.",

        aim_autoshoot_title = "Auto Shoot",
        aim_autoshoot_desc  = "Clicks mouse when locked on target",
        aim_autoshoot_sub   = "Uses fire rate mode timing.",

        aim_silent_title    = "Silent Aim",
        aim_silent_desc     = "Camera stays still, mouse.Hit is redirected",
        aim_silent_sub      = "Your view doesn't move but shots land on target.",

        aim_fovfilter_title = "FOV Filter",
        aim_fovfilter_desc  = "Only lock targets inside FOV circle",
        aim_fovfilter_sub   = "Actually checks screen pixel distance now.",

        aim_indicator_title = "Target Indicator + Line",
        aim_indicator_desc  = "Dot on target + line from crosshair",
        aim_indicator_sub   = "Visual lock confirmation.",

        aim_fovpulse_title  = "FOV Pulse",
        aim_fovpulse_desc   = "Animated FOV circle when aiming",
        aim_fovpulse_sub    = "Breathing effect feedback.",

        aim_autoswitch_title= "Auto Switch",
        aim_autoswitch_desc = "Re-acquire after elimination",
        aim_autoswitch_sub  = "Auto-lock next enemy on kill.",

        aim_mode_title      = "Aim Mode",
        aim_mode_desc       = "Toggle=press E on/off | Hold=hold E",

        aim_priority_title  = "Priority",
        aim_priority_desc   = "Closest / Lowest HP / Nearest to crosshair",

        aim_firerate_title  = "Fire Rate",
        aim_firerate_desc   = "Normal 0.15s | Fast 0.06s | Uzi 0.01s",

        aim_smooth_title    = "Smoothness",
        aim_smooth_desc     = "1=very slow, 100=instant snap",
        aim_smooth_sub      = "Use 50-80 for legit, 100 for rage.",

        aim_fovrad_title    = "FOV Radius",
        aim_fovrad_desc     = "Screen pixel radius for target filtering",
        aim_fovrad_sub      = "Larger=easier lock, smaller=precise.",

        aim_maxdist_title   = "Max Distance",
        aim_maxdist_desc    = "Max stud range for targets",
        aim_maxdist_sub     = "Default: 1000",

        aim_predict_title   = "Prediction",
        aim_predict_desc    = "Lead shots on moving targets",
        aim_predict_sub     = "0=none, higher=more lead.",

        -- Rage tab
        rage_master_title   = "RAGE MODE",
        rage_master_desc    = "Master switch for all rage features",
        rage_master_sub     = "Enables snap/hitbox/aura/antiaim.",

        rage_snap_title     = "Snap Aim",
        rage_snap_desc      = "Instant camera lock, no smoothing",
        rage_snap_sub       = "Overrides smoothness.",

        rage_hitbox_title   = "Hitbox Expander",
        rage_hitbox_desc    = "Expand enemy hitboxes client-side",
        rage_hitbox_sub     = "Updated every 0.5s for performance.",

        rage_aura_title     = "Kill Aura",
        rage_aura_desc      = "Auto-attack nearby enemies",
        rage_aura_sub       = "Throttled to 0.15s intervals.",

        rage_antiaim_title  = "Anti-Aim",
        rage_antiaim_desc   = "Manipulate your character rotation",
        rage_antiaim_sub    = "8 CS2-style modes available.",

        rage_resolver_title = "Resolver",
        rage_resolver_desc  = "Force aim to real Head position",
        rage_resolver_sub   = "Bypass enemy anti-aim.",

        rage_hitbox_cycle   = "Rage Hitbox",
        rage_hitbox_cycledesc = "Which part to aim in rage mode",

        rage_antiaim_style  = "Anti-Aim Style",
        rage_antiaim_styledesc = "CS2-style anti-aim modes",

        rage_hitboxsize_title = "Hitbox Size",
        rage_hitboxsize_desc  = "Expansion size in studs",
        rage_hitboxsize_sub   = "5-8 moderate, 15+ extreme.",

        rage_aurarange_title = "Aura Range",
        rage_aurarange_desc  = "Attack distance in studs",
        rage_aurarange_sub   = "Default: 15",

        rage_aaspeed_title  = "AA Speed",
        rage_aaspeed_desc   = "Rotation/jitter speed multiplier",
        rage_aaspeed_sub    = "Higher=faster.",

        rage_aapitch_title  = "AA Pitch",
        rage_aapitch_desc   = "Vertical angle override (degrees)",
        rage_aapitch_sub    = "0=normal, -89=look up, 89=look down.",

        -- Visuals tab
        vis_chams_title     = "Dual CHAMS",
        vis_chams_desc      = "Green=visible, Red=behind wall",
        vis_chams_sub       = "Smart raycasted color chams.",

        vis_esp_title       = "Legacy ESP",
        vis_esp_desc        = "Single-color highlights (when chams off)",
        vis_esp_sub         = "Team color based outlines.",

        vis_fov_title       = "FOV Circle",
        vis_fov_desc        = "Show targeting circle",
        vis_fov_sub         = "Threat boundary ring.",

        vis_visible_opacity = "Visible Opacity",
        vis_visible_desc    = "Green chams fill transparency",
        vis_visible_sub     = "0=solid, 1=invisible.",

        vis_occluded_opacity= "Occluded Opacity",
        vis_occluded_desc   = "Red chams fill transparency",
        vis_occluded_sub    = "0=solid, 1=invisible.",

        vis_esp_opacity     = "ESP Opacity",
        vis_esp_desc2       = "Legacy ESP transparency",
        vis_esp_sub2        = "Only when chams off.",

        -- Customization tab
        cust_targetpart_prefix = "LEGIT TARGET: ",
        cust_torso             = "TORSO",
        cust_head              = "HEAD",
        cust_swapcolor         = "SWAP ACCENT COLOR",
        cust_chams_legend      = "CHAMS Legend",
        cust_chams_desc        = "GREEN=Visible/Shoot | RED=Wall/Blocked",
        cust_ui_trans_title    = "UI Transparency",
        cust_ui_trans_desc     = "Menu background opacity",
        cust_ui_trans_sub      = "0=solid, 100=invisible.",
        cust_border_title      = "Border Width",
        cust_border_desc       = "Frame border thickness",
        cust_border_sub        = "Pixel width.",

        -- Settings tab
        sett_save           = "SAVE CONFIG",
        sett_saved          = "SAVED!",
        sett_reset          = "RESET DEFAULTS",
        sett_discord        = "COPY DISCORD",
        sett_discord_copied = "COPIED!",
        sett_unload         = "UNLOAD ENGINE",

        -- Discord modal
        discord_name        = "c0rrosion",
        discord_tagline     = "Cmon Join",
        discord_invite_btn  = "Invite",
        discord_body        = "Join Discord for changelogs, help, and announcements.",
        discord_link        = "https://discord.gg/8jSF8vSvbJ",
        discord_ready       = "Ready when you are",
        discord_copy_btn    = "Copy Discord",
        discord_later_btn   = "Maybe Later",

        -- Logs
        log_initialized     = "Engine v39 Initialized.",
        log_perf            = "Performance: Throttled chams/hitbox/aura.",
        log_silent          = "Silent Aim hook loaded.",
        log_all_ready       = "All modules ready. v39 loaded.",
        log_locked          = "Locked: ",
        log_eliminated      = "Eliminated: ",
        log_saved           = "Config saved.",
        log_reset           = "Reset to defaults.",

        -- Add to en table:
        sett_lang           = "Switch Language",
        sett_lang_current   = "Current: English",
        sett_lang_switched  = "Language switched.",

        tab_movement          = "Movement",
        bhop_title            = "Bunny Hop",
        bhop_mode_title       = "Bhop Mode",
        bhop_accel_title      = "Bhop Acceleration",
        bhop_maxspeed_title   = "Max Air Speed",
        strafe_title          = "Air Strafe",
        strafe_mode_title     = "Strafe Mode",
        strafe_strength_title = "Strafe Strength",
    },

    zh = {
        menu_title          = "Aim Hub Next",
        menu_subtitle       = "作者 @Rakamo82 | Aim Hub Next 魔改作者 CookieLee",
        btn_close           = "X",
        btn_minimize        = "—",
        btn_restore         = "+",

        label_active        = "● 运行中",
        label_shortcuts     = "快捷键",
        shortcut_template   = "[%s] 瞄准 (%s): %s\n[RShift] 最小化\n暴力: %s | 静默: %s",
        shortcut_on         = "开",
        shortcut_off        = "关",
        btn_system_status   = "系统运行中",

        search_placeholder  = "搜索功能...",

        tab_aimlock         = "锁定瞄准",
        tab_rage            = "暴力模式",
        tab_visuals         = "视觉 / ESP",
        tab_logs            = "系统日志",
        tab_customization   = "自定义",
        tab_settings        = "设置",

        aim_master_title    = "系统总开关",
        aim_master_desc     = "所有系统的主开关",
        aim_master_sub      = "启用/禁用整个引擎。",

        aim_wallcheck_title = "穿墙检测",
        aim_wallcheck_desc  = "跳过墙后目标（使用射线检测）",
        aim_wallcheck_sub   = "改进的射线检测。",

        aim_autoshoot_title = "自动射击",
        aim_autoshoot_desc  = "锁定目标后自动点击鼠标",
        aim_autoshoot_sub   = "使用射速模式计时。",

        aim_silent_title    = "静默瞄准",
        aim_silent_desc     = "视角不动，鼠标.Hit重定向",
        aim_silent_sub      = "视角不移动但子弹命中目标。",

        aim_fovfilter_title = "FOV过滤",
        aim_fovfilter_desc  = "只锁定FOV圆圈内目标",
        aim_fovfilter_sub   = "实际检测屏幕像素距离。",

        aim_indicator_title = "目标指示器+连线",
        aim_indicator_desc  = "目标上圆点+准星连线",
        aim_indicator_sub   = "视觉锁定确认。",

        aim_fovpulse_title  = "FOV脉冲",
        aim_fovpulse_desc   = "瞄准时FOV圆圈动画",
        aim_fovpulse_sub    = "呼吸效果反馈。",

        aim_autoswitch_title= "自动切换",
        aim_autoswitch_desc = "击杀后重新获取目标",
        aim_autoswitch_sub  = "击杀后自动锁定下一个敌人。",

        aim_mode_title      = "瞄准模式",
        aim_mode_desc       = "切换=按E开关 | 按住=按住E",

        aim_priority_title  = "目标优先级",
        aim_priority_desc   = "最近/最低血量/最近准星",

        aim_firerate_title  = "射速",
        aim_firerate_desc   = "普通0.15s | 快速0.06s | Uzi 0.01s",

        aim_smooth_title    = "平滑度",
        aim_smooth_desc     = "1=非常慢, 100=瞬间锁定",
        aim_smooth_sub      = "合法50-80, 暴力100。",

        aim_fovrad_title    = "FOV半径",
        aim_fovrad_desc     = "目标过滤屏幕像素半径",
        aim_fovrad_sub      = "越大越容易锁定。",

        aim_maxdist_title   = "最大距离",
        aim_maxdist_desc    = "目标最大格距离",
        aim_maxdist_sub     = "默认: 1000",

        aim_predict_title   = "预测",
        aim_predict_desc    = "对移动目标提前量",
        aim_predict_sub     = "0=无, 越高提前量越大。",

        rage_master_title   = "暴力模式",
        rage_master_desc    = "所有暴力功能的主开关",
        rage_master_sub     = "启用瞬锁/判定/光环/反瞄准。",

        rage_snap_title     = "瞬间锁定",
        rage_snap_desc      = "无平滑的摄像机锁定",
        rage_snap_sub       = "覆盖平滑设置。",

        rage_hitbox_title   = "判定扩大",
        rage_hitbox_desc    = "客户端扩大敌人判定框",
        rage_hitbox_sub     = "每0.5s更新一次。",

        rage_aura_title     = "击杀光环",
        rage_aura_desc      = "自动攻击附近敌人",
        rage_aura_sub       = "每0.15s节流。",

        rage_antiaim_title  = "反瞄准",
        rage_antiaim_desc   = "操控角色旋转",
        rage_antiaim_sub    = "8种CS2风格模式。",

        rage_resolver_title = "解算器",
        rage_resolver_desc  = "强制瞄准真实头部位置",
        rage_resolver_sub   = "绕过敌方反瞄准。",

        rage_hitbox_cycle    = "暴力判定部位",
        rage_hitbox_cycledesc= "暴力模式瞄准部位",

        rage_antiaim_style   = "反瞄准风格",
        rage_antiaim_styledesc = "CS2风格反瞄准模式",

        rage_hitboxsize_title = "判定框大小",
        rage_hitboxsize_desc  = "扩展尺寸（格）",
        rage_hitboxsize_sub   = "5-8适中, 15+极端。",

        rage_aurarange_title = "光环范围",
        rage_aurarange_desc  = "攻击距离（格）",
        rage_aurarange_sub   = "默认: 15",

        rage_aaspeed_title  = "AA速度",
        rage_aaspeed_desc   = "旋转/抖动速度倍数",
        rage_aaspeed_sub    = "越高越快。",

        rage_aapitch_title  = "AA俯仰角",
        rage_aapitch_desc   = "垂直角度覆盖（度）",
        rage_aapitch_sub    = "0=正常, -89=向上, 89=向下。",

        vis_chams_title     = "双色CHAMS",
        vis_chams_desc      = "绿=可见, 红=在墙后",
        vis_chams_sub       = "智能射线检测颜色标记。",

        vis_esp_title       = "传统ESP",
        vis_esp_desc        = "单色高亮（关闭CHAMS时）",
        vis_esp_sub         = "基于队伍颜色的轮廓。",

        vis_fov_title       = "FOV圆圈",
        vis_fov_desc        = "显示瞄准圆圈",
        vis_fov_sub         = "威胁范围圆环。",

        vis_visible_opacity = "可见不透明度",
        vis_visible_desc    = "绿色CHAMS填充透明度",
        vis_visible_sub     = "0=实心, 1=不可见。",

        vis_occluded_opacity= "遮挡不透明度",
        vis_occluded_desc   = "红色CHAMS填充透明度",
        vis_occluded_sub    = "0=实心, 1=不可见。",

        vis_esp_opacity     = "ESP不透明度",
        vis_esp_desc2       = "传统ESP透明度",
        vis_esp_sub2        = "仅在CHAMS关闭时有效。",

        cust_targetpart_prefix = "合法目标: ",
        cust_torso             = "躯干",
        cust_head              = "头部",
        cust_swapcolor         = "切换强调色",
        cust_chams_legend      = "CHAMS图例",
        cust_chams_desc        = "绿色=可见/射击 | 红色=墙/阻挡",
        cust_ui_trans_title    = "UI透明度",
        cust_ui_trans_desc     = "菜单背景不透明度",
        cust_ui_trans_sub      = "0=实心, 100=不可见。",
        cust_border_title      = "边框宽度",
        cust_border_desc       = "框架边框粗细",
        cust_border_sub        = "像素宽度。",

        sett_save           = "保存配置",
        sett_saved          = "已保存！",
        sett_reset          = "恢复默认",
        sett_discord        = "复制Discord",
        sett_discord_copied = "已复制！",
        sett_unload         = "卸载引擎",

        discord_name        = "c0rrosion",
        discord_tagline     = "快来加入吧",
        discord_invite_btn  = "邀请",
        discord_body        = "加入Discord获取更新日志、帮助和公告。",
        discord_link        = "https://discord.gg/8jSF8vSvbJ",
        discord_ready       = "随时欢迎",
        discord_copy_btn    = "复制Discord",
        discord_later_btn   = "以后再说",

        log_initialized     = "引擎 v39 已初始化。",
        log_perf            = "性能: CHAMS/判定/光环已节流。",
        log_silent          = "静默瞄准钩子已加载。",
        log_all_ready       = "所有模块就绪。v39 已加载。",
        log_locked          = "已锁定: ",
        log_eliminated      = "已击杀: ",
        log_saved           = "配置已保存。",
        log_reset           = "已恢复默认设置。",

        -- Add to zh table:
        sett_lang           = "切换语言",
        sett_lang_current   = "当前: 中文",
        sett_lang_switched  = "语言已切换。",

        tab_movement          = "移动增强",
        bhop_title            = "连跳",
        bhop_mode_title       = "连跳模式",
        bhop_accel_title      = "连跳加速度",
        bhop_maxspeed_title   = "最大空中速度",
        strafe_title          = "空中扫射",
        strafe_mode_title     = "扫射模式",
        strafe_strength_title = "扫射强度",
    },
}

-- Active language (default: English)
local currentLang = "en"

function i18n.SetLanguage(code)
    if languages[code] then
        currentLang = code
    else
        warn("[i18n] Unknown language code: " .. tostring(code) .. ", falling back to 'en'")
        currentLang = "en"
    end
end

function i18n.Get(key)
    local langTable = languages[currentLang]
    if langTable and langTable[key] ~= nil then
        return langTable[key]
    end
    -- Fallback to English
    local fallback = languages["en"]
    if fallback and fallback[key] ~= nil then
        return fallback[key]
    end
    -- Last resort: return the key itself so nothing breaks
    return key
end

-- Shorthand alias
function i18n.T(key)
    return i18n.Get(key)
end

function i18n.GetAvailableLanguages()
    local list = {}
    for code, _ in pairs(languages) do
        table.insert(list, code)
    end
    return list
end

return i18n