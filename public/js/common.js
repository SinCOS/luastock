var tabIndex = 0;
var element = null;
login = function () {
    destoryStorage();
    layer.open({
        type: 1,
        content: $('#login_frm').html(),
        area: [
            '400px', '400px'
        ]
    });
}
getUserId = function () {
    if (localStorage.userID !== null) {
        return localStorage['userID'];
    }
    return false;
}
register = function () {
    layer.open({
        type: 1,
        content: $("#register_frm").html(),
        area: [
            '400px', '400px'
        ]
    });
}
buy_vip = function () {
    layer.open({
        type:1,
        content:$("#vip_frm").html(),
        area:[
            '400px','400px'
        ]
    });
}
function destoryStorage() {
    localStorage.clear();
}
function saveUserFavor(result) {
    if (result) {
        localStorage['userFavor'] = JSON.stringify(result);

    }

}
shutdown = function () {
    if (localStorage.token) {
        Vue.http.headers.common['Authorization'] = localStorage['token'];
    } else {
        return false;
    }

    if (localStorage.userID) {
        destoryStorage();
    }
    Vue.http.get('/user/logoff').then(function (resp) {

    }).catch(function (resp) {

    }).finally(function (resp) {
        window.location = "/";
    });
}
layui.use(['element', 'form'], function () {
    element = layui.element();
    var form = layui.form();
    form.verify({
        username: function (value) {
            if (!new RegExp("^[a-zA-Z0-9_\u4e00-\u9fa5\\s·]+$").test(value)) {
                return '用户名不能有特殊字符';
            }
            if (/(^\_)|(\__)|(\_+$)/.test(value)) {
                return '用户名首尾不能出现下划线\'_\'';
            }
            if (/^\d+\d+\d$/.test(value)) {
                return '用户名不能全为数字';
            }
            if (/([\s])/.test(value)) {
                return '用户名不能出现空格';
            }
        },
        pass: [/(.+){6,12}$/, '密码必须6到12位'],
    });
    form.on('submit(formDemo)', function (data) {
        $.post('/user/login', data.field, function (data, textStatus, xhr) {
            if (data.status == 200) {
                localStorage['userID'] = data.result.userID;
                localStorage['token'] = data.result.token;
                app.reflushFavor();
                window.location = "/";
                return;
            } else {
                layer.msg(data.message);
            }
        }, 'json').fail(function (resp) {
            if (resp.responseJSON) {
                layer.msg(resp.responseJSON.message);
            } else {
                layer.msg('系统异常')
            }
        });
        return false;
    });
    form.on('submit(regfrm)', function (data) {
        $.post('/user/register', data.field, function (data, status) {
            layer.msg(data.message);
            if (data.status == 200) {
                login();
            }
        }, 'json').fail(function (resp) {
            if (resp.responseJSON) {
                layer.msg(resp.responseJSON.message);
            } else {
                layer.msg('系统异常')
            }

        });

        return false;
    });
    element.on('tab(sysctrl)', function (data) {
        app.$data.tabIndex = data.index;
        console.log(JSON.stringify(data));
    });
});

function check_time(m) {
    if (m < 10) return "0" + m;
    return m;
}

function getTime(i) {
    var d = new Date();
    var h = d.getHours();
    var m = d.getMinutes();
    if (h == 9) {
        if (m <= 30) {
            return h + ":" + (30);
        }
    } else if (h == 11) {
        if (m > 30) {
            if (i > 0) {
                return h + ":" + (30 - i);
            }
        }
    } else if (h == 12) {
        if (i > 0) {
            return 11 + ":" + (30 - i);
        }
    }
    if (h >= 15) {
        if (i > 0) {
            return "14:" + (60 - i);
        }
        return "15:00";
    }
    if (m == 0 && i > 0) {
        return (h - 1) + ":" + (60 - i);
    } else if (m == 0 && i == 0) {
        return h + ":00";
    }
    if (m <= 10) {
        if (i > 0) {
            return h + ":" + check_time(m - i);
        }

    }
    return h + ":" + check_time(m - i);
}



// Vue.http.options.emulateJSON = true;

    app = new Vue({
        el: "#app",
        data: {
            loginIn: false,
            userInfo: [],
            userFavor: [],
            favorIndex: 0,
            tabIndex: tabIndex,
            favorClickIndex: false,
            favorselectIndex: 0,
            echarts: null,
            reflush_url: '',
            time: {
                current_time: '',
                last_one: '',
                last_two: '',
                last_three: ''
            }
        },
        created: function () {
            var userID = getUserId();
            console.log(userID);
            var self = this;
            if (localStorage['token']) {
                Vue.http.headers.common['Authorization'] = localStorage['token'];
            }
            if (!userID) {
                return;
            }
            this.$http.get('/user/info').then(function (resp) {
                self.userInfo = resp.body.result;

                if (self.userInfo.username && self.userInfo.username !== '') {
                    self.loginIn = true;
                    if (self.loginIn && localStorage['userFavor']) {
                        var _userFavor = JSON.parse(localStorage['userFavor']);
                        if (_userFavor) {
                            self.userFavor = _userFavor;
                            self.favorIndex = _userFavor[0]['id'];
                        } else {
                            app.reflushFavor();
                        }
                    } else {
                        app.reflushFavor();
                    }
                } else {
                    destoryStorage();
                }

            }, function (resp) {
                destoryStorage();
                self.loginIn = false;
            });
            console.log(self.loginIn);
            this.reflushTime();

        },
        updated: function(){
          layui.element().init();
        },
        watch: {
            loginIn: function (newV, oldV) {
              

            }
        },
        mounted: function () {
            
        },
        methods: {
            favorManger: function () {
                layer.open({
                    type: 1,
                    content: $("#favor_manger"),
                    area: ['320px', '400px']
                });
            },
            rmGroup: function (group_id) {
                var self = this;
                layer.confirm('是否删除', function (index) {
                    self.$http.delete('/user/group/' + group_id)
                        .then(function (resp) {
                            layer.msg(resp.body.message);
                            if (resp.body.status == 200) {
                                self.reflushFavor();
                            }
                        }).catch(function (resp) {
                            layer.msg("操作失败");
                        });
                    layer.close(index);
                });
            },
            reflushTime: function () {
                this.time.last_one = getTime(1);
                this.time.last_two = getTime(2);
                this.time.last_three = getTime(3);
            },
            reflushFavor: function () {
                var self = this;
                this.$http.get('/user/category').then(function (resp) {
                    if (resp.body.status == 200) {

                        self.userFavor = JSON.parse(resp.body.result);
                        saveUserFavor(self.userFavor);
                    }
                }).catch(function (fail) {
                    console.log(JSON.stringify(fail));
                });
            },
            favor_select: function (id) {
                this.favorIndex = id;
            },
            vip_click: function (id) {
                if (!this.loginIn) {
                    login();
                    return false;
                }
                this.reflush_url = "/" + id + "/vip";
            },
            favor_click: function (id, _public) {
                var _private = _public || 0
                var self = this;
                if (id == 0 && _private == 0) {
                    self.reflush_url = '';
                    this.favorClickIndex = false;
                } else if (_private == 0) {
                    self.reflush_url = '/' + id + '/0';
                    this.favorClickIndex = false;
                } else {
                    self.reflush_url = '/' + id;
                    this.favorClickIndex = true;
                }
                this.favorselectIndex = id;
            },
            save_favor: function (cpy_id) {
                var self = this;
                if (self.favorIndex == 0) {
                    layer.msg('请选择分类');
                    return false;
                }
                this.$http.post('/user/favor/' + cpy_id, {
                    sg_id: self.favorIndex
                }).then(function (resp) {
                    layer.msg(resp.body.message);
                }).catch(function ($resp) {
                    layer.msg('网络错误');
                });
                return true;
            }
        }
    });
