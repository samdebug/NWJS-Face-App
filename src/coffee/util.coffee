prefix_wwn = "iqn.2013-01.net.zbx.initiator"
temp_data = []
server_type = { store: '', header: true, type: ''}
global_Interval = []
compare_Interval = []
compare_result = []
compare_card = []
compare_temp = []
random = ""
disks_type = 
    enterprise:[
        'ST4000NM0033'
        'ST3000NM0033'
        'ST2000NM0033'
        'ST1000NM0033'
        'WD1000FYYZ'
        'WD2000FYYZ'
        'WD3000FYYZ'
        'WD4000FYYZ'
        'HUS723040ALA640'
        'MG03ACA300']
    monitor:[
        'ST8000VX0002'
        'ST1000VX000'
        'ST2000VX000'
        'ST3000VX000'
        'ST3000VX006'
        'ST4000VX000'
        'WD10PURX'
        'WD20PURX'
        'WD30PURX'
        'WD40PURX']
    sas:[
        'WD3001FYYG'
        'ST2000NM0023']
random_id = (prefix) ->
    nr = Math.floor(Math.random()*Math.pow(2,32))
    "#{prefix}#{nr}"

sector_to_mb = (sector) -> sector/2/1024
sector_to_gb = (sector) -> sector/2/1024/1024
sector_to_tb = (sector) -> sector/2/1024/1024/1024
mb_to_sector = (mb) -> mb*1024*2
gb_to_sector = (gb) -> gb*1024*1024*2
tb_to_sector = (tb) -> tb*1024*1024*1024*2
cap_to_sector = (cap, unit) ->
    unit = unit.toUpperCase()
    switch unit
        when "MB"
            return mb_to_sector cap
        when "GB"
            return gb_to_sector cap
        when "TB"
            return tb_to_sector cap

subitems = (items, templ) ->
    _templ = (item, templ) ->
        o = {}
        for attr, v of templ
            o[attr] = if attr of item then item[attr] else v
        return o
    (_templ(item, templ) for item in items)

subitems_key = (items, templ) ->
    _templ = (item, templ) ->
        o = {}
        for attr, v of templ
            o[attr] = if v of item then item[v] else ''
        return o
    (_templ(item, templ) for item in items)

arr_remove = (items, item) ->
    index = items.indexOf item
    if index isnt -1 then items.splice index, 1
    items

unique = (arr) ->
    result = []

    for item in arr
        is_unique = true
        for result_item in result
            if result_item is item
                is_unique = false
                break
        result.push item if is_unique
    
    result

base_data = []

this.random = random
this.base_data = base_data
this.compare_temp = compare_temp
this.compare_card = compare_card
this.compare_result = compare_result
this.global_Interval = global_Interval
this.compare_Interval = compare_Interval
this.prefix_wwn = prefix_wwn
this.disks_type = disks_type
this.subitems = subitems
this.subitems_key = subitems_key
this.arr_remove = arr_remove
this.cap_to_sector = cap_to_sector
this.gb_to_sector = gb_to_sector
this.mb_to_sector = mb_to_sector
this.random_id = random_id
this.sector_to_gb = sector_to_gb
this.sector_to_mb = sector_to_mb
this.sector_to_tb = sector_to_tb
this.server_type = server_type
this.tb_to_sector = tb_to_sector
this.unique = unique
this.temp_data = temp_data
