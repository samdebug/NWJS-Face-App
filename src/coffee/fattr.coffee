health = (val) ->
    switch val
        when "failed"
            return "<span class='label label-important'>损坏</span>"
        when "down"
            return "<span class='label label-important'>下线</span>"
        when "degraded"
            return "<span class='label label-warning'>降级</span>"
        else
            return "<span class='label label-success'>正常</span>"

role = (val) ->
    switch val
        when "data"
            return "<span class='label label-success'>数据盘</span>"
        when "unused"
            return "<span class='label label-info'>未使用</span>"
        when "spare"
            return "<span class='label label-warning'>热备盘</span>"
        when "data&spare"
            return "<span class='label label-warning'>数据热备盘</span>"
        when "global_spare"
            return "<span class='label label-warning'>全局热备盘</span>"

rebuilding = (rebuilding, rebuild_progress) ->
    if not rebuilding
        "<span class='label label-success'>否</span>"
    else
        "#{(rebuild_progress*100).toFixed(2)}%"

synchronizing = (v) ->
    avail =parseInt v.sync_progress*100
    if v.sync_progress == 1
        return "<span class='label label-success'> 完成</span>"
    else if 0 <= v.sync_progress < 1 and v.syncing == false or v.sync == false
        return "<a href='javascript:;' class='btn mini blue ' style='width:34px'><i class='icon-play' style='float:left'></i> #{ avail}%</a>"
    else if v.syncing == true or v.sync_progress == 0 or v.sync == true
        return "<a href='javascript:;' class='btn mini blue ' style='width:70px'><i class='icon-pause'  style='float:left'></i> 同步中 #{ avail}%</a>"
    else if v.sync_progress == 0 and v.syncing == false
        return "<a href='javascript:;' class='btn mini green '><i class='icon-ok'></i> 开启</a>"
 
precreating = (precreate_progress) ->
        "<span class='label label-warning'>#{precreate_progress}%</span>"
        
cap_usage_vol = (cap, used) ->
    avail =parseInt cap/2/1024/1024/1024
    type = "TB"
    if avail <= 0
        avail = cap/2/1024/1024
        type = "GB"
    if avail <= 0
        avail = cap/2/1024
        type = "MB"
    """<span>#{avail}#{type}</span>
       <div class="bar bar-danger" style="width:0"></div>
       <div class="bar" style="width:100%"></div>
    """

cap_usage_raid = (cap, used) ->
    used_ratio = used/cap
    if used == 0
        used_ratio = 0
    else if used_ratio < 0.01
        used_ratio = 1
    else
        used_ratio = parseInt used_ratio*100
    avail_ratio = 100-used_ratio
    avail = parseInt (cap-used)/2/1024/1024

    """<span>可用#{avail}GB</span>
       <div class="bar bar-danger" style="width:#{used_ratio}%"></div>
       <div class="bar" style="width:#{avail_ratio}%"></div>
    """

cap = (val) ->
    value = val/2/1024/1024
    # "#{ value.toFixed(2).replace(/\.?0*$/, "") }GB"
    "#{ value | 0 }GB"

caps = (val) ->
    # "#{ value.toFixed(2).replace(/\.?0*$/, "") }GB"
    value = val/1024/1024
    "#{ value | 0 }GB"
    
raid = (val) ->
    if val? then val else 'N/A'

host = (val) ->
    switch val
        when "native"
            return "<span class='label label-success'>本地</span>"
        when "foreign"
            return "<span class='label label-info'>第三方</span>"
        when "used"
            return "<span class='label label-warning'>分区</span>"

_import = (val) ->
    switch val
        when "native"
            return "<span class='label label-success'>不需要</span>"
        when "foreign"
            return "<a href='javascript:;' class='btn mini yellow init-disk'><i class='icon-eraser'></i> 格式化</a>"
        when "used"
            return "<a href='javascript:;' class='btn mini yellow init-disk'><i class='icon-eraser'></i> 格式化</a>"

active_session = (val) ->
    if val
        return "<span class='label label-success'>连接中</span>"
    else
        return "<span class='label label-info'>未连接</span>"
        
show_link = (val) ->
    if val
        return true
    else
        return false
        
cap_usage = (cap, used, type) ->
    used_ratio = used/cap
    if used == 0
        used_ratio = 0
    else if used_ratio < 0.01
        used_ratio = 1
    else
        used_ratio = parseInt used_ratio*100
    avail_ratio = 100-used_ratio
    if type =="GB"
        avail = parseInt (cap-used)/2/1024/1024
    else if type =="MB"
        avail = parseInt (cap-used)/2/1024
    else
        avail = parseInt (cap-used)/2/1024/1024/1024

    """<span>可用#{avail}#{type}</span>
       <div class="bar bar-danger" style="width:#{used_ratio}%"></div>
       <div class="bar" style="width:#{avail_ratio}%"></div>
    """

disk_status = (role, raidcolor, slot) ->
    style = ''
    if role is "unused" #有盘，没使用
        return "<span class='label label-disk-normal-noraid'>#{slot}</span>"
    else if role is "nodisk" #空槽位
        return "<span class='label label-nodisk-noraid'>#{slot}</span>"
    else if role is "down"
        switch raidcolor
            when "color1"
                return "<span class='label label-nodisk-raid1'>#{slot}</span>"
            when "color2"
                return "<span class='label label-nodisk-raid2'>#{slot}</span>"
            when "color3"
                return "<span class='label label-nodisk-raid3'>#{slot}</span>"
            when "color4"
                return "<span class='label label-nodisk-raid4'>#{slot}</span>"
    else if role is "global_spare"
        return "<span class='label label-disk-globalspare'>#{slot}</span>"
    else if role is "kicked"
        switch raidcolor
            when "color0"
                return "<span class='label label-disk-unormal'>#{slot}</span>"
            when "color1"
                return "<span class='label label-disk-unormal-raid1'>#{slot}</span>"
            when "color2"
                return "<span class='label label-disk-unormal-raid2'>#{slot}</span>"
            when "color3"
                return "<span class='label label-disk-unormal-raid3'>#{slot}</span>"
            when "color4"
                return "<span class='label label-disk-unormal-raid4'>#{slot}</span>"        
    else
        if role is "spare"
            style = 'color:#CC7A00'
        switch raidcolor
            when "color1" 
                return "<span class='label label-disk-normal-raid1' style='#{style}'>#{slot}</span>"
            when "color2"
                return "<span class='label label-disk-normal-raid2' style='#{style}'>#{slot}</span>"
            when "color3"
                return "<span class='label label-disk-normal-raid3' style='#{style}'>#{slot}</span>"
            when "color4"
                return "<span class='label label-disk-normal-raid4' style='#{style}'>#{slot}</span>"

raid_status = (name, color) ->
    switch color
        when "color1"
            return "<span style='float:left'>#{name} :</span><div style='border:2px; background:#45d1e3; float:left; width:20px; height:20px'></div>"
        when "color2"
            return "<span style='float:left'>#{name} :</span><div style='border:2px; background:#ffb848; float:left; width:20px; height:20px'></div>"
        when "color3"
            return "<span style='float:left'>#{name} :</span><div style='border:2px; background:#1a1de3; float:left; width:20px; height:20px'></div>"
        when "color4"
            return "<span style='float:left'>#{name} :</span><div style='border:2px; background:#852b99; float:left; width:20px; height:20px'></div>"
        when "color5"
            return "<span style='float:left'>全局热备 :</span><div style='border:2px; background:#e30f1b; float:left; width:20px; height:20px'></div>"

server_status = (session) ->
    if session
        return "<span class='label label-success'>已配置</span>"
    else
        return "<span class='label label-warning'>未配置</span>"
        
server_health = (session) ->
    if session
        return "<span class='label label-success'>可用</span>"
    else
        return "<span class='label label-important'>不可用</span>"
process = (i) ->
    """<div class="bar" style="width:#{i}%"></div>"""
process_step = (i) ->
    """<span style='font-size: 15px;font-weight: bold;color: rgb(35, 138, 233);'>(步骤#{i}/3)</span>"""
    
show_server = (session) ->
    if session
        return true
    else
        return false
        
journal_status = (level) ->
    switch level
        when "info"
            return "<span class='label label-success'><i class='icon-volume-up'></i>提醒</span>"
        when "warning"
            return "<span class='label label-warning'><i class='icon-warning-sign'></i>警告</span>"
        when "critical"
            return "<span class='label label-important'><i class='icon-remove'></i>错误</span>"
            
monitor_status = (total,online) ->
        if online isnt 0
            rate = online / total
            if rate is 1
                return "<span class='label label-success' style='border-radius: 20px !important;'><i class='icon-like'></i>良好</span>"
            else if  0.8 < rate < 1
                return "<span class='label label-warning' style='border-radius: 20px !important;'><i class='icon-warning-sign'></i>警告</span>"
            else
                return "<span class='label label-important' style='border-radius: 20px !important;'><i class='icon-remove'></i>危险</span>"
        else
            return "<span class='label label-success' style='border-radius: 20px !important;'><i class='icon-volume-up'></i>良好</span>"

view_status = (rate,alarm,alarm_type) ->
        if alarm_type is ""
            if 0 <= rate <=30
                return "<span class='label label-success' style='border-radius: 20px !important;'><i class='icon-like'></i>良好</span>"
            else if  30 < rate <= 60
                return "<span class='label label-warning' style='border-radius: 20px !important;'><i class='icon-warning-sign'></i>警告</span>"
            else
                return "<span class='label label-important' style='border-radius: 20px !important;'><i class='icon-remove'></i>危险</span>"
        else
            for i in alarm
                if i.type is alarm_type
                    if 0 <= rate <= i.normal
                        return "<span class='label label-success' style='border-radius: 20px !important;'><i class='icon-like'></i>良好</span>"
                    else if  i.normal < rate <= i.warning
                        return "<span class='label label-warning' style='border-radius: 20px !important;'><i class='icon-warning-sign'></i>警告</span>"
                    else
                        return "<span class='label label-important' style='border-radius: 20px !important;'><i class='icon-remove'></i>危险</span>"

view_status_fixed = (rate) ->
        if 0 <= rate <=30
            return "<span class='label label-success' style='border-radius: 20px !important;'><i class='icon-like'></i>良好</span>"
        else if  30 < rate <= 60
            return "<span class='label label-warning' style='border-radius: 20px !important;'><i class='icon-warning-sign'></i>警告</span>"
        else
            return "<span class='label label-important' style='border-radius: 20px !important;'><i class='icon-remove'></i>危险</span>"
            
machine_status =(e) =>
    if e
        return "<span class='label label-success' style='padding: 5px;border-radius: 20px !important;'><i class='icon-like'></i>良好</span>"
    else
        return "<span class='label label-warning' style='padding: 5px;border-radius: 20px !important;'><i class='icon-warning-sign'></i>警告</span>"

monitor_status = (session) ->
    if session
        return "<span class='label label-success'>在线</span>"
    else
        return "<span class='label label-important'>掉线</span>"
        
compare_status = (session) ->
        if session is "未对比"
            return "<span class='label' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>未对比</span>"
        else if session is "正在上传图片"
            return "<span class='label label-info' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>正在上传图片</span>"
        else if session is "很抱歉,不通过"
            return "<span class='label label-important' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>不通过</span>"
        else if session is  "恭喜你,通过"
            return "<span class='label label-info' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>通过</span>"
        else if session is "对比次数已用完，请充值"
            return "<span class='label label-important' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>对比次数已用完，请充值</span>"
        else if session is "读卡器未连接"
            return "<span class='label label-important' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>读卡器未连接</span>"
        else if session is "读卡失败"
            return "<span class='label label-important' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>读卡失败</span>"
        else if session is "未安装驱动"
            return "<span class='label label-important' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>未安装驱动</span>"
        else if session is "已通过"
            return "<span class='label label-info' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>已通过</span>"
        else if session is "对比完成"
            return "<span class='label label-info' style='vertical-align: text-top;margin-right: 10px;border-radius: 10px !important;'>对比完成</span>"
        else
            return "<span style='vertical-align: text-top;font-size: 12px;padding-right: 14px;color: rgb(136, 136, 136);color: #169EF4;'>#{session}</span>"

fattr = health: health, role: role, rebuilding: rebuilding, cap_usage_vol: cap_usage_vol, cap: cap, raid: raid,\
        host: host, _import: _import, active_session: active_session, cap_usage: cap_usage, cap_usage_raid: cap_usage_raid,\
        disk_status: disk_status, raid_status: raid_status,show_link:show_link,synchronizing:synchronizing, precreating: precreating,\
        server_status:server_status,show_server:show_server ,server_health:server_health,process:process,process_step:process_step,\
        journal_status:journal_status, caps:caps, monitor_status:monitor_status,view_status:view_status,machine_status:machine_status, \
        monitor_status:monitor_status,view_status_fixed:view_status_fixed,compare_status:compare_status

this.fattr = fattr
