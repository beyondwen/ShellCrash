decode_uri_field() {
    printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%/\\x/g')"
}

escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

escape_yaml_single() {
    printf '%s' "$1" | sed "s/'/''/g"
}

build_json_string_array() {
    [ -z "$1" ] && return 0
    old_ifs=$IFS
    IFS=','
    set -- $1
    IFS=$old_ifs
    json_items=''
    for item in "$@"; do
        item=$(decode_uri_field "$item" | sed 's/^ *//; s/ *$//')
        [ -z "$item" ] && continue
        item=$(escape_json "$item")
        json_items=$(echo "$json_items, \"$item\"" | sed 's/^, //')
    done
    printf '%s' "$json_items"
}

build_yaml_list() {
    [ -z "$1" ] && return 0
    old_ifs=$IFS
    IFS=','
    set -- $1
    IFS=$old_ifs
    for item in "$@"; do
        item=$(decode_uri_field "$item" | sed 's/^ *//; s/ *$//')
        [ -z "$item" ] && continue
        printf "      - '%s'\n" "$(escape_yaml_single "$item")"
    done
}

parse_hysteria2_uri() {
    hy2_uri=$1
    hy2_name=${2:-Hysteria2}
    hy2_body=${hy2_uri#*://}
    hy2_query=''
    case "$hy2_body" in
    *\?*)
        hy2_query=${hy2_body#*\?}
        hy2_body=${hy2_body%%\?*}
        ;;
    esac

    hy2_userinfo=${hy2_body%@*}
    hy2_hostport=${hy2_body#*@}
    [ "$hy2_userinfo" = "$hy2_body" ] && {
        msg_alert "\033[31m$CORECFG_HY2_BAD_URI\033[0m"
        return 1
    }

    hy2_password=$(decode_uri_field "$hy2_userinfo")
    case "$hy2_hostport" in
    \[*\]:*)
        hy2_server=${hy2_hostport%%]*}
        hy2_server=${hy2_server#[}
        hy2_port=${hy2_hostport##*:}
        ;;
    *:*)
        hy2_server=${hy2_hostport%:*}
        hy2_port=${hy2_hostport##*:}
        ;;
    *)
        msg_alert "\033[31m$CORECFG_HY2_BAD_URI\033[0m"
        return 1
        ;;
    esac
    hy2_server=$(decode_uri_field "$hy2_server")
    echo "$hy2_port" | grep -Eq '^[0-9]+$' || {
        msg_alert "\033[31m$CORECFG_HY2_BAD_URI\033[0m"
        return 1
    }

    hy2_insecure=false
    hy2_tls_server_name=''
    hy2_tls_server_name_line=''
    hy2_alpn=''
    hy2_alpn_line=''
    hy2_obfs_type=''
    hy2_obfs_password=''
    hy2_obfs_block=''
    hy2_up=''
    hy2_up_line=''
    hy2_down=''
    hy2_down_line=''
    old_ifs=$IFS
    IFS='&'
    set -- $hy2_query
    IFS=$old_ifs
    for item in "$@"; do
        [ -z "$item" ] && continue
        hy2_key=${item%%=*}
        [ "$hy2_key" = "$item" ] && hy2_value='' || hy2_value=${item#*=}
        hy2_key=$(decode_uri_field "$hy2_key")
        hy2_value=$(decode_uri_field "$hy2_value")
        case "$hy2_key" in
        insecure)
            case "$(echo "$hy2_value" | tr 'A-Z' 'a-z')" in
            1|true|yes|on)
                hy2_insecure=true
                ;;
            *)
                hy2_insecure=false
                ;;
            esac
            ;;
        sni|peer)
            hy2_tls_server_name=$hy2_value
            ;;
        alpn)
            hy2_alpn=$hy2_value
            ;;
        obfs)
            hy2_obfs_type=$hy2_value
            ;;
        obfs-password)
            hy2_obfs_password=$hy2_value
            ;;
        up|upmbps)
            echo "$hy2_value" | grep -Eq '^[0-9]+([.][0-9]+)?$' && hy2_up=$hy2_value
            ;;
        down|downmbps)
            echo "$hy2_value" | grep -Eq '^[0-9]+([.][0-9]+)?$' && hy2_down=$hy2_value
            ;;
        esac
    done

    return 0
}

gen_hysteria2_singbox_direct() {
    hy2_name_json=$(escape_json "$hy2_name")
    hy2_server_json=$(escape_json "$hy2_server")
    hy2_password_json=$(escape_json "$hy2_password")
    [ -n "$hy2_tls_server_name" ] && hy2_tls_server_name_line='        "server_name": "'"$(escape_json "$hy2_tls_server_name")"'",'
    hy2_alpn_json=$(build_json_string_array "$hy2_alpn")
    [ -n "$hy2_alpn_json" ] && hy2_alpn_line='        "alpn": ['"$hy2_alpn_json"'],'
    echo "$hy2_up" | grep -Eq '^[0-9]+([.][0-9]+)?$' && hy2_up_line='      "up_mbps": '"$hy2_up"','
    echo "$hy2_down" | grep -Eq '^[0-9]+([.][0-9]+)?$' && hy2_down_line='      "down_mbps": '"$hy2_down"','
    if [ -n "$hy2_obfs_type" ]; then
        hy2_obfs_type=$(escape_json "$hy2_obfs_type")
        if [ -n "$hy2_obfs_password" ]; then
            hy2_obfs_password=$(escape_json "$hy2_obfs_password")
            hy2_obfs_block=$(cat <<EOF
      "obfs": {
        "type": "$hy2_obfs_type",
        "password": "$hy2_obfs_password"
      },
EOF
)
        else
            hy2_obfs_block=$(cat <<EOF
      "obfs": {
        "type": "$hy2_obfs_type"
      },
EOF
)
        fi
    fi

    mkdir -p "$CRASHDIR"/jsons
    . "$CRASHDIR"/starts/check_core.sh
    check_core || return 1
    cat >"$TMPDIR"/hy2_config.json <<EOF
{
  "outbounds": [
    {
      "tag": "🚀 节点选择",
      "type": "selector",
      "outbounds": ["♻️ 自动选择", "$hy2_name_json", "DIRECT"]
    },
    {
      "tag": "🀄️ 国内流量",
      "type": "selector",
      "outbounds": ["DIRECT", "🚀 节点选择"]
    },
    {
      "tag": "🐟 漏网之鱼",
      "type": "selector",
      "outbounds": ["🚀 节点选择", "DIRECT"]
    },
    {
      "tag": "♻️ 自动选择",
      "type": "urltest",
      "outbounds": ["$hy2_name_json"],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "3m",
      "tolerance": 100
    },
    {
      "tag": "$hy2_name_json",
      "type": "hysteria2",
      "server": "$hy2_server_json",
      "server_port": $hy2_port,
$hy2_up_line
$hy2_down_line
      "password": "$hy2_password_json",
$hy2_obfs_block
      "tls": {
        "enabled": true,
$hy2_tls_server_name_line
$hy2_alpn_line
        "insecure": $hy2_insecure
      }
    },
    {
      "tag": "DIRECT",
      "type": "direct"
    },
    {
      "tag": "REJECT",
      "type": "block"
    },
    {
      "tag": "GLOBAL",
      "type": "selector",
      "outbounds": ["🚀 节点选择", "DIRECT"]
    }
  ],
  "route": {
    "rule_set": [
      {
        "tag": "cn",
        "type": "remote",
        "format": "binary",
        "path": "./ruleset/cn.srs",
        "url": "https://testingcf.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/cn.srs",
        "download_detour": "DIRECT"
      }
    ],
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "DIRECT"
      },
      {
        "rule_set": ["cn"],
        "outbound": "🀄️ 国内流量"
      }
    ],
    "auto_detect_interface": false,
    "final": "🐟 漏网之鱼"
  }
}
EOF
    if "$TMPDIR"/CrashCore format -c "$TMPDIR"/hy2_config.json >"$TMPDIR"/hy2_format.json 2>&1; then
        mv -f "$TMPDIR"/hy2_config.json "$CRASHDIR"/jsons/config.json
        rm -f "$TMPDIR"/hy2_format.json
        msg_alert "\033[32m$CORECFG_HY2_GEN_OK\033[0m"
        prompt_apply_generated_config
        return 0
    else
        rm -f "$TMPDIR"/hy2_config.json
        msg_alert "\033[31m$CORECFG_HY2_GEN_FAILED\033[0m"
        return 1
    fi
}

gen_hysteria2_singbox() {
    case "$crashcore" in
    *singbox*)
        ;;
    *)
        msg_alert "\033[33m$CORECFG_HY2_ONLY_SUPPORTED_CORE\033[0m"
        return 1
        ;;
    esac

    parse_hysteria2_uri "$1" "$2" || return 1

    mkdir -p "$CRASHDIR"/providers
    provider_tag=$(printf '%s' "$hy2_name" | sed 's/[^A-Za-z0-9._-]/_/g')
    [ -z "$provider_tag" ] && provider_tag='Hysteria2'
    . "$CRASHDIR"/libs/urlencode.sh
    provider_name=$(urlencode "$hy2_name")
    provider_file="./providers/${provider_tag}_hy2_uri"
    provider_path="$CRASHDIR/${provider_file#./}"
    printf '%s#%s\n' "$hy2_uri" "$provider_name" >"$provider_path"

    . "$CRASHDIR"/menus/providers_singbox.sh
    gen_providers "$hy2_name" "$provider_file" "3" "12" "clash.meta" && return 0

    msg_alert "\033[33m$CORECFG_HY2_PROVIDER_FALLBACK\033[0m"
    gen_hysteria2_singbox_direct
}

gen_hysteria2_mihomo() {
    case "$crashcore" in
    meta)
        ;;
    *)
        msg_alert "\033[33m$CORECFG_HY2_ONLY_SUPPORTED_CORE\033[0m"
        return 1
        ;;
    esac

    parse_hysteria2_uri "$1" "$2" || return 1

    hy2_name_yaml=$(escape_yaml_single "$hy2_name")
    hy2_server_yaml=$(escape_yaml_single "$hy2_server")
    hy2_password_yaml=$(escape_yaml_single "$hy2_password")
    hy2_sni_line=''
    hy2_alpn_block=''
    hy2_alpn_line=''
    hy2_up_line=''
    hy2_down_line=''
    hy2_obfs_line=''
    hy2_obfs_password_line=''
    [ -n "$hy2_tls_server_name" ] && hy2_sni_line="    sni: '$(escape_yaml_single "$hy2_tls_server_name")'"
    hy2_alpn_block=$(build_yaml_list "$hy2_alpn" | sed 's/^/  /')
    [ -n "$hy2_alpn_block" ] && hy2_alpn_line="    alpn:
$hy2_alpn_block"
    echo "$hy2_up" | grep -Eq '^[0-9]+([.][0-9]+)?$' && hy2_up_line="    up: '$(escape_yaml_single "$hy2_up Mbps")'"
    echo "$hy2_down" | grep -Eq '^[0-9]+([.][0-9]+)?$' && hy2_down_line="    down: '$(escape_yaml_single "$hy2_down Mbps")'"
    [ -n "$hy2_obfs_type" ] && hy2_obfs_line="    obfs: '$(escape_yaml_single "$hy2_obfs_type")'"
    [ -n "$hy2_obfs_password" ] && hy2_obfs_password_line="    obfs-password: '$(escape_yaml_single "$hy2_obfs_password")'"

    mkdir -p "$CRASHDIR"/providers
    provider_tag=$(printf '%s' "$hy2_name" | sed 's/[^A-Za-z0-9._-]/_/g')
    [ -z "$provider_tag" ] && provider_tag='Hysteria2'
    provider_file="./providers/${provider_tag}_hy2.yaml"
    provider_path="$CRASHDIR/${provider_file#./}"
    cat >"$provider_path" <<EOF
proxies:
  - name: '$hy2_name_yaml'
    type: hysteria2
    server: '$hy2_server_yaml'
    port: $hy2_port
    password: '$hy2_password_yaml'
$hy2_up_line
$hy2_down_line
$hy2_obfs_line
$hy2_obfs_password_line
$hy2_sni_line
    skip-cert-verify: $hy2_insecure
$hy2_alpn_line
EOF

    . "$CRASHDIR"/menus/providers_clash.sh
    gen_providers "$hy2_name" "$provider_file" "3" "12" "clash.meta"
}
