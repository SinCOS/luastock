$(function(){


    login = function() {
        destoryStorage();
        layer.open({
            type: 1,
            content: $('#login_frm').html(),
            area: [
                '400px', '400px'
            ]
        });
    }
    getUserId = function() {
        if (localStorage.userID !== null) {
            return localStorage['userID'];
        }
        return false;
    }
    register = function() {
        layer.open({
            type: 1,
            content: $("#register_frm").html(),
            area: [
                '400px', '400px'
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
    shutdown = function() {
        if(localStorage.token){
             Vue.http.headers.common['Authorization'] = localStorage['token'];
        }else{
            return false;
        }
       
        if (localStorage.userID) {
            destoryStorage();
        }
        Vue.http.get('/user/logoff').then(function(resp){

        }).catch(function(resp){
            
        }).finally(function(resp){
            window.location = "/";
        });
        
        
    }
    layui.use(['element', 'form'], function() {
        var element = layui.element();
        var form = layui.form();
        form.on('submit(formDemo)', function(data) {
            if (data.field.username.length < 5) {
                layer.msg('用户名长度不能少于5个字符');
                return false;
            }
            if (data.field.password.length < 6) {
                layer.msg('密码长度太短');
                return false;
            }
            $.post('/user/login', data.field, function(data, textStatus, xhr) {
                if (data.status == 200) {
                    localStorage['userID'] = data.result.userID;
                    localStorage['token'] = data.result.token;
                    app.reflushFavor();
                    window.location = "/";
                    return;
                } else {
                    layer.msg(data.message);
                }
            }, 'json');
            return false;
        });
        form.on('submit(register_frm)', function(data) {
            
        });

    });
     function check_time(m){
        if (m < 10 ) return "0"+m;
        return m;
    }
    function getTime(i){
            var d = new Date();
            var h = d.getHours();
            var m = d.getMinutes();
            if (h == 9){
                if (m <= 30) {                    
                         return  h + ":" +  (30);
                }
            }
            else if(h == 11){
                if(m > 30){
                    if(i > 0 ){
                        return h + ":" + (30 -i);
                    }
                }
            }
            else if(h == 12 ){
                if(i > 0 ){
                     return 11 + ":" + (30 -i);
                }
            }
            if(h >= 15){
                if (i >0) {
                    return "15:" + (60 -i);
                }
                return "15:00";
            }
            if (m == 0 && i > 0 ){
                return (h -1) + ":" + (60 -i);
            }else if( m==0 && i == 0){
                return h + ":00";
            }
            if(m <= 10){
                if( i > 0 ){
                    return h + ":0" + check_time(m-i);
                }

            }
            return  h + ":" +  check_time(m-i);
    }

    Vue.http.options.emulateJSON = true;
    app = new Vue({
        el: "#app",
        data: {
            loginIn: false,
            userInfo: [],
            userFavor: [],
            favorIndex: 0,
            favorClickIndex: false,
            favorselectIndex: 0,
            echarts: null,
            time:{
                current_time: '',
                last_one:'',
                last_two:'',
                last_three:''
            }
        },
        updated: function() {
            layui.element().init();
        },
        created: function() {
            var userID = getUserId();
            console.log(userID);
            var self = this;
            if(localStorage['token']){
                Vue.http.headers.common['Authorization'] = localStorage['token'];
            }
            if (!userID) {
                return;
            }
            this.$http.get('/user/info').then(function(resp) {
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

            },function(resp){
                self.loginIn = false;
            });
            console.log(self.loginIn);
            this.reflushTime();

        },
        watch: {
            loginIn: function(newV, oldV) {
                layui.element().init();
            }
        },
        mounted: function() {
            
            //layui.element().init();

        },
        methods: {
            reflushTime:function(){
                this.time.last_one = getTime(1);
                this.time.last_two = getTime(2);
                this.time.last_three = getTime(3);
            },
            reflushFavor: function() {
                var self = this;
                this.$http.get('/user/category').then(function(resp) {
                    if (resp.body.status == 200) {

                        self.userFavor = JSON.parse(resp.body.result);
                        saveUserFavor(self.userFavor);
                    }
                }).catch(function(fail){
                    console.log(JSON.stringify(fail));
                });
            },
            favor_select: function(id) {
                this.favorIndex = id;
            },
            favor_click: function(id, _public ) {
                var _private = _public || 0
                if (id == 0 && _private == 0) {
                    table_info.stock_url = stock_url;
                    this.favorClickIndex = false;
                    table_info.current.ajax.reload();
                } else if (_private == 0) {
                    table_info.stock_url = stock_url + '/' + id + '/0';
                    this.favorClickIndex = false;
                    table_info.current.ajax.reload();
                } else {
                    table_info.stock_url = stock_url + '/' + id;
                    this.favorClickIndex = true;
                    table_info.current.ajax.reload();
                }
                this.favorselectIndex = id;
            },
            save_favor: function(cpy_id) {
                var self = this;
                if (self.favorIndex == 0) {
                    layer.msg('请选择分类');
                    return false;
                }
                this.$http.post('/user/favor/' + cpy_id, { sg_id: self.favorIndex }).then(function(resp) {
                    layer.msg(resp.body.message);
                }).catch(function($resp){
                    layer.msg('网络错误');
                });
                return true;
            }
        }
    });

});
