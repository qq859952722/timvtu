#!/bin/sh

touch /config.json

# V2Ray new configuration
cat <<-EOF > /config.json
{
    "log": {
        "loglevel": "error"
    },
    "reverse": {
        // 这是 A 的反向代理设置，必须有下面的 bridges 对象
        "bridges": [{
                "tag": "bridge", // 关于 A 的反向代理标签，在路由中会用到
                "domain": "private.cloud.com" // A 和 B 反向代理通信的域名，可以自己取一个，可以不是自己购买的域名，但必须跟下面 B 中的 reverse 配置的域名一致
            }
        ]
    },
    "inbounds": [{
            "port": 3333,
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": false,
                "ip": "127.0.0.1",
                "userLevel": 0
            },
            "tag": "in-0",
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {}
            }
        }, {
            "tag": "in-1",
            "protocol": "vmess",
            "port": ${PORT},
            "settings": {
                "clients": [{
                        "id": "${UUID}",
                        "level": 1,
                        "alterId": 8
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/"
                }
            }
        }
    ],
    "outbounds": [{
            //A连接B的outbound
            "tag": "tunnel", // A 连接 B 的 outbound 的标签，在路由中会用到
            "protocol": "vmess",
            "settings": {
                "vnext": [{
                        "address": "${RIP}", // B 地址，IP 或 实际的域名
                        "port": ${RPORT},
                        "users": [{
                                "id": "${UUID}",
                                "alterId": 8
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "mkcp",
                "kcpSettings": {
                    "uplinkCapacity": 5,
                    "downlinkCapacity": 100,
                    "congestion": true,
                    "header": {
                        "type": "dtls"
                    }
                }
            }
        },
        // 另一个 outbound，最终连接私有网盘
        {
            "protocol": "freedom",
            "settings": {},
            "tag": "out"
        }
    ],
    "routing": {
        "rules": [{
                // 配置 A 主动连接 B 的路由规则
                "type": "field",
                "inboundTag": [
                    "bridge"
                ],
                "domain": [
                    "full:private.cloud.com"
                ],
                "outboundTag": "tunnel"
            }, {
                // 反向连接访问私有网盘的规则
                "type": "field",
                "inboundTag": [
                    "bridge"
                ],
                "outboundTag": "out"
            }, {
                // 本地socket连接出口
                "type": "field",
                "inboundTag": [
                    "in-0"
                ],
                "outboundTag": "out"
            }, {
                // 本地socket连接出口
                "type": "field",
                "inboundTag": [
                    "in-1"
                ],
                "outboundTag": "out"
            }
        ]
    }
}
EOF
/v2ray -config=/config.json
