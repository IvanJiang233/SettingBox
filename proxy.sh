#! /bin/bash

# Author: TomJanory
# Version: 1.0

uuid=""
mydomain=""
ssl_path="/var/www/ssl/"
trojan_passwd="mytrojan"

##################################
# 用于标记信息种类
message_type() {
    case $1 in
        1)  echo -e -n "\033[32m[Success]\033[0m:";;
        2)  echo -e -n "\033[31m[Fail]\033[0m:";;
        3)  echo -e -n "\033[33m[Warning]\033[0m:";;
        4)  echo -e -n "\033[36m[Waiting]\033[0m";;
        *)  echo -e -n "\033[34m[Info]\033[0m:"
    esac
}

# show类的函数主要用于显示Apps信息
show_xray_paths() {
    echo "$(message_type 0)xray paths: "
    echo -e "(\033[32m*\033[0m)\tconfig.json: /usr/local/etc/xray/config.json"
    echo -e "\tbin: /usr/local/bin/xray"
    echo -e "\tservice: /etc/systemd/system/xray.service"
    echo -e "\tservice: /etc/systemd/system/xray@.service"
    echo -e "\tgeoip: /usr/local/share/xray/geoip.dat"
    echo -e "\tgeosite: /usr/local/share/xray/geosite.dat"
    echo -e "\taccess.log: /var/log/xray/access.log"
    echo -e "\terror.log: /var/log/xray/error.log"
}

show_caddy_paths() {
    echo "$(message_type 0)caddy paths: "
    echo -e "(\033[32m*\033[0m)\tCaddyfile: /etc/caddy/Caddyfile"
    echo -e "\tbin: /usr/bin/caddy"
    echo -e "\twww: /usr/share/caddy(默认) /var/www/mydomain(配置后)"
}

show_settings() {
    echo "$(message_type 5)Xray服务器设置(任选一种使用): "
    echo "1.vless + xtls + tcp"
    echo -e "\tserver/SNI: $mydomain"
    echo -e "\tuuid: $uuid"
    echo -e "\tport: 443"
    echo -e "\tflow: xtls-rprx-direct"
    echo -e "\tnetwork: tls"
    echo -e "\ttls: xtls"
    echo "2.trojan"
    echo -e "\tserver: $mydomain"
    echo -e "\tport: 443"
    echo -e "\tpassword: $trojan_passwd"
    echo "3.vless + websocket + tcp"
    echo -e "\tserver/SNI: $mydomain"
    echo -e "\tuuid: $uuid"
    echo -e "\tnetwork: ws"
    echo -e "\tpath: /news"
    echo -e "\ttls: tls"
}

###################################
# 功能性函数: 安装curl
install_curl() {
    [[ $(apt list --installed 2>&1 | awk 'BEGIN{i=0}/^curl\//{i++}END{print i}') -eq 0 ]] && (echo "$(message_type 4)正在安装curl工具"; (apt-get install -y curl &> /dev/null))
    [[ $(apt list --installed 2>&1 | awk 'BEGIN{i=0}/^curl\//{i++}END{print i}') -eq 0 ]] && echo "$(message_type 2)curl工具未安装" || echo "$(message_type 1)curl工具已安装"
}

# 功能性函数：修改源
sources_rechange() {
    if [[ $(grep -c debians.org < /etc/apt/sources.list) -ne 0 ]]; then
        cp /etc/apt/sources.list /etc/apt/sources.$(date +%m-%d-%Y).list &> /dev/null
        echo "deb http://mirrors.cloud.tencent.com/debian buster main contrib non-free" > /etc/apt/sources.list
        echo "deb http://mirrors.cloud.tencent.com/debian buster-updates main contrib non-free" >> /etc/apt/sources.list
        echo "deb http://mirrors.cloud.tencent.com/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list
        apt-get update &> /dev/null
        echo "$(message_type 1)已更新源文件，当前源为腾讯云"
        echo -e "$(message_type 0)(\033[32m*\033[0m)sources.list path: /etc/apt/sources.list"
    else
        echo "$(message_type 3)源文件已非官方源，不进行更新"
    fi
}

# 功能性函数：开启bbr
open_bbr() {
    if [[ $(lsmod | grep -c bbr) -eq 0 ]]; then
        if [[ $(sysctl net.ipv4.tcp_congestion_control | grep -c bbr) -eq 0 ]]; then
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        fi
        sysctl -p &> /dev/null
    fi
    [[ $(lsmod | grep -c bbr) -ne 0 ]] && echo "$(message_type 1)系统已开启bbr" || echo "$(message_type 2)系统未开启bbr"
}

# 功能性函数：安装caddy
install_caddy() {
    if [[ $(apt list --installed 2>&1 | awk 'BEGIN{i=0}/^caddy\//{i++}END{print i}') -eq 0 ]]; then
        # 官方安装Caddy方法
        echo "$(message_type 4)正在将Caddy添加到apt"
        apt install -y debian-keyring debian-archive-keyring apt-transport-https &> /dev/null
        echo "$(message_type 5)添加apt-key: $(curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | apt-key add -)"
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null   
    fi
    apt-get update &> /dev/null
    echo "$(message_type 4)正在安装Caddy服务器"
    apt-get install caddy &> /dev/null
    [[ $(apt list --installed 2>&1 | awk 'BEGIN{i=0}/^caddy\//{i++}END{print i}') -ne 0 ]] && (echo "$(message_type 1)Caddy服务器已安装"; show_caddy_paths) || echo "$(message_type 2)Caddy服务器未安装"
}

# 功能性函数：安装xray
install_xray() {
    # 官方安装脚本 + curl的安静模式
    echo "$(message_type 4)正在安装Xray-Core"
    bash -c "$(curl -s -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /etc/null
    [[ $(xray -h | awk 'BEGIN{i=0}/^Usage./{i++}END{print i}') -ne 0 ]] && (echo "$(message_type 1)Xray-Core已安装"; show_xray_paths) || echo "$(message_type 2)Xray-Core未安装"
}

# 功能性函数：根据选择的模板，配置xray和caddy $1: 选择的模板序号
setting_xray() {
    # 从官方模板下载并修改
    case $1 in
        1)
            # vless-xtls-trojan/ws
            curl -s -L https://raw.githubusercontent.com/IvanJiang233/SettingBox/main/config.json > /usr/local/etc/xray/config.json
            awk -v uuid=$uuid '{if (/"id"/) sub(/myuuid/,uuid);print $0 > "/usr/local/etc/xray/config.json"}' /usr/local/etc/xray/config.json
            awk -v path_crt="$ssl_path$mydomain.crt" '{if (/"certificateFile"/) sub(/path_crt/,path_crt);print $0 > "/usr/local/etc/xray/config.json"}' /usr/local/etc/xray/config.json
            awk -v path_key="$ssl_path$mydomain.key" '{if (/"keyFile"/) sub(/path_key/,path_key);print $0 > "/usr/local/etc/xray/config.json"}' /usr/local/etc/xray/config.json
            awk -v trojan_passwd="$trojan_passwd" '{if (/"password"/) sub(/mypassword/,trojan_passwd);print $0 > "/usr/local/etc/xray/config.json"}' /usr/local/etc/xray/config.json
            ;;
    esac 
    systemctl restart xray
    [[ $? -ne 0 ]] && echo "$(message_type 3)配置xray出现错误" || echo "$(message_type 1)配置xray成功"
}

# 功能性函数：配置caddy
setting_caddy() {
    [ ! -d "/var/www/$mydomain" ] && mkdir -p /var/www/$mydomain
    [ -d "/var/www/$mydomain" ] && echo "$(message_type 1)创建网站根目录成功" || echo "$(message_type 3)创建网站根目录失败"
    cp /usr/share/caddy/index.html "/var/www/$mydomain"
    [[ $? -ne 0 ]] && echo "$(message_type 3)复制index网页错误" || echo "$(message_type 1)复制index网页成功"
    case $1 in
        1)
            # 此配置用于接收回落到80端口的流量，进而分流到搭建的伪装网站上(网站可以用来放些常需要下载的东西，或者个人博客)
            curl -s -L https://raw.githubusercontent.com/IvanJiang233/SettingBox/main/Caddyfile > /etc/caddy/Caddyfile
            awk -v mydomain=$mydomain '{if (/mydomain/) gsub(/mydomain/, mydomain);print $0 > "/etc/caddy/Caddyfile"}' /etc/caddy/Caddyfile
            ;;
    esac
    systemctl reload caddy
    [[ $? -ne 0 ]] && echo "$(message_type 3)配置caddy出现错误" || echo "$(message_type 1)配置caddy成功"
}

# 功能性函数: 备份配置文件
backup_settings() {
    echo "$(message_type 4)正在将配置文件备份到~/$(date +%m-%d-%Y)文件夹中"
    mkdir -p ~/$(date +%m-%d-%Y)
    [[ $? -ne 0 ]] && echo "$(message_type 3)创建目录错误" || echo "$(message_type 1)创建目录成功"
    cp /usr/local/etc/xray/config.json ~/$(date +%m-%d-%Y)
    [[ $? -ne 0 ]] && echo "$(message_type 3)备份xray配置文件错误" || echo "$(message_type 1)备份xray配置文件成功"
    cp /etc/caddy/Caddyfile ~/$(date +%m-%d-%Y)
    [[ $? -ne 0 ]] && echo "$(message_type 3)备份caddy配置文件错误" || echo "$(message_type 1)备份caddy配置文件成功"
}

###################################
# 汇总函数: 检查预先环境
check_enviroment() {
    install_curl
}

# 汇总函数: 安装apps
install_apps() {
    install_xray
    install_caddy
}

# 汇总函数: 设置apps
setting_apps() {
    setting_xray $1
    setting_caddy $2
}

###################################
# 选择函数: 选择操作
make_choise_operations() {
    case $1 in
        1)
            draw_start
            sources_rechange
            draw_end
            ;;
        2)
            draw_start
            open_bbr
            draw_end
            ;;
        3)
            draw_start
            sources_rechange
            open_bbr
            check_enviroment
            install_apps
            echo "$(message_type 4)请输入配置Xray和Caddy所需信息: "
            read -p "您的域名(如: baidu.com): " mydomain
            read -p "Trojan密码(默认为mytrojan): " trojan_passwd
            uuid=$(cat /proc/sys/kernel/random/uuid)
            setting_apps 1 1
            show_settings
            draw_end
            ;;
        4)
            draw_template_list
            ;;
        5)
            draw_start
            show_xray_paths
            show_caddy_paths
            draw_end
            ;;
        6)
            draw_start
            backup_settings
            draw_end
            ;;
        0)
            draw_start
            echo "$(message_type 1)已退出脚本"
            echo ""
            echo "======================================"
            exit
            ;;
        *)
            read -p "请选择列表中的操作: " num_op
            make_choise_operations $num_op
            ;;
    esac
}

# 选择函数: 选择模板
make_choise_templates() {
    # 从官方推荐模板下载并修改
    case $1 in
        1)
            draw_start
            echo "$(message_type 4)请输入配置Xray和Caddy所需信息: "
            read -p "输入您的域名(如: baidu.com): " mydomain
            read -p "设定Trojan密码(默认为mytrojan): " trojan_passwd
            uuid=$(cat /proc/sys/kernel/random/uuid)
            setting_apps 1 1
            draw_end
            ;;
        0)
            draw_menu
            ;;
        *)
            read -p "请选择已有的模板: " num_template 
            make_choise_templates $num_template
            ;;
    esac
}

###################################
# draw类的函数主要用于显示菜单
draw_start() {
    printf "\033c"
    echo "===============正在执行==============="
}

draw_end() {
    echo ""
    echo "======================================"
    read -n1 -p "按任意键返回菜单"
}

draw_template_list() {
    printf "\033c"
    echo "===============模板列表==============="
    echo "1.caddy伪装 vless-xtls-trojan/ws (一键安装的默认选项)"
    echo "0.返回主菜单"
    echo ""
    echo "======================================"
    read -p "请选择一个模板: " template
    make_choise_templates $template
}

draw_waiting_input() {
    echo ""
    echo "======================================"
    read -n1 -p "按任意键返回" temp
}

draw_menu() {
    printf "\033c"
    echo "===============操作列表==============="
    echo "1.修改源 (一般不用修改)"
    echo "2.开启bbr (推荐开启)"
    echo "3.一键安装"
    echo "4.选择方案安装"
    echo "5.查看paths (默认路径，无论有无安装)"
    echo "6.备份配置文件"
    echo "0.退出脚本"
    echo ""
    echo "====================================="
    read -p "请选择操作：" num
    make_choise_operations $num
    draw_menu
}

###################################
# main函数
main() {
    echo "$(message_type 4)正在更新源"
    apt-get update &> /dev/null
    [[ $EUID -ne 0 ]] && (echo "$(message_type 2)当前非管理员权限,请使用su root切换至管理员再执行此脚本"; exit)
    if [ ! -d "$ssl_path" ]; then
        echo "$(message_type 2)执行脚本之前，请确保以下步骤被正确执行: "
        echo -e "\t1.创建/var/www/ssl文件夹"
        echo -e "\t2.将自己的ssl证书复制至ssl文件夹中 (.crt和.key)"
        echo -e "\t3.将.crt和.key文件，命名为mydomain.crt和mydomain.key (如: baidu.com.crt baidu.com.key)"
        exit
    fi
    draw_menu
}

main "$@"