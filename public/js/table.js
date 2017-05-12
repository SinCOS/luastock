var inteval = null;

function jsk(aoData) {
    var u = {}
    u = aoData[0]

    //alert(u.dtaw)
    var arr = {},
        b = {},
        c = {}
    for (i = 0; i < aoData.length; i++) {
        //k=JSON.stringify(aoData[i].name)
        k = aoData[i].name
        if (typeof arr[k] == 'object') {
            b = JSON.stringify(arr[k])
            c = JSON.stringify(b.data)
            alert(b)
        } else {
            arr[k] = aoData[i].value
        }
    }
    return arr
}


function build_datables(table) {
    var Language = { // 汉化
        "sProcessing": "正在加载数据...",
        "sLengthMenu": "显示_MENU_条 ",
        "sZeroRecords": "没有您要搜索的内容",
        "sInfo": "从_START_ 到 _END_ 条记录——总记录数为 _TOTAL_ 条",
        "sInfoEmpty": "记录数为0",
        "sInfoFiltered": "(全部记录数 _MAX_  条)",
        "sInfoPostFix": "",
        "sSearch": "搜索",
        "sUrl": "",
        "oPaginate": {
            "sFirst": "第一页",
            "sPrevious": " 上一页 ",
            "sNext": " 下一页 ",
            "sLast": " 最后一页 "
        }
    };
    var datables_params = {
        "aaSorting": [
            [8, "desc"]
        ],
        "oLanguage": Language,

        "processing": true, //载入数据的时候是否显示“载入中”
        "serverSide": true, //生成get数据
        "columns": table.columns,
        "fnServerData": function (sSource, aoData, fnCallback) {

            $.ajax({
                    url: table.stock_url,
                    type: 'GET',
                    dataType: 'json',
                    data: jsk(aoData),
                })
                .done(function (resp) {
                    fnCallback(resp);
                }).fail(function (resp) {
                    var json = resp.responseJSON;
                    if (json.status == 404) {
                        login();
                    } else if (json.status == 403) {
                        buy_vip()
                        layer.msg(json.message);
                    }

                });


        },
        "fnRowCallback": function (nRow, aData, iDisplayIndex) {
            var page = table.current.page();
            var page_len = table.current.page.len();
            $('td:eq(0)', nRow).text(page * page_len + iDisplayIndex + 1);
            var $object = null;;

            $object = $('td:eq(11)', nRow);

            $object.addClass('cpy_id').attr('data', aData['cpy_id']).on('click', function () {
                var self = this;
                var cpy_id = $(this).attr('data');
                var cpy_name = $(this).attr("cpy_name");
                var _title = $(self).text();
                if (_title == '取消关注') {
                    Vue.http.delete('/user/favor/' + app.$data.favorselectIndex + '/' + cpy_id).then(
                        function ($resp) {
                            layer.msg($resp.body.message)
                            if ($resp.body.status == 200) {
                                setTimeout(function () {
                                    table.current.ajax.reload();
                                }, 2000);
                            }
                        }).catch(function ($resp) {
                        alert("删除失败");
                    });

                    return false;
                }
                if (!app.$data.loginIn) {
                    login();
                    return false;
                }
                var layer_index = layer.open({
                    type: 1,
                    title: '自选股收藏夹',
                    content: $("#favor"),
                    area: ['345px', '435px'],
                    btn: ['新建', '确认'],
                    yes: function (index, layero) {
                        layer.prompt({
                            title: '新建收藏夹'
                        }, function (value, iindex, elem) {
                            if (!value || value == '') {
                                return false;
                            }
                            Vue.http.post('/user/category', {
                                name: value
                            }, {
                                headers: {
                                    "Content-type": "application/x-www-form-urlencoded"
                                }
                            }).then(function (resp) {
                                if (resp.body.status == 400) {
                                    layer.msg(resp.body.message);
                                    setTimeout(function () {
                                        login();
                                    }, 3000);

                                } else if (resp.body.status == 200) {
                                    app.reflushFavor();

                                }

                            }, function (resp) {
                                layer.msg('网络连接失败!!!');
                            });

                            layer.close(iindex);
                        });

                    },
                    btn2: function () {
                        if (app.save_favor(cpy_id)) {
                            return true;
                        }

                    }
                });
                return false;
            }).attr('cpy_name', aData['name']).html(app.$data.favorClickIndex ? '<a href="javascipt:void;">取消关注</a>' : '<a href="javascipt:void;">关注</a>').css({
                "cursor": 'pointer'
            });;
            bgColor(aData['zf'], 9, nRow);
            bgColor(aData['zs'], 10, nRow);
            if (table.stock_url.indexOf('ddx') > 0) {
                $('td:eq(3)', nRow).text(aData['zlbfb'] + '%');
                bgColor(aData['zljb'], 4, nRow);
                bgColor(aData['two'], 5, nRow);
                bgColor(aData['one'], 6, nRow);
                bgColor(aData['lst_ddxCache'], 7, nRow);
                bgColor(aData['three'], 8, nRow);
            } else if (table.stock_url.indexOf('jlr') > 0) {
                $('td:eq(3)', nRow).text(aData['zlbfb'] + '%');
                bgColor(aData['jlr'], 4, nRow);
                bgColor(aData['two'], 5, nRow);
                bgColor(aData['one'], 6, nRow);
                bgColor(aData['calc'], 7, nRow);
                bgColor(aData['three'], 8, nRow);
            } else if (table.stock_url.indexOf('nszl') > 0) {
                bgColor(aData['nxjlrjh'], 3, nRow);
                bgColor(aData['nxjlrch'], 4, nRow);
                bgColor(aData['nxjlr'], 5, nRow);
                bgColor(aData['jhcs'], 6, nRow);
                bgColor(aData['chcs'], 7, nRow);
                bgColor(aData['jcc'],8,nRow);
              
            }

            return nRow;
        }
    };
    return datables_params;
}
Vue.component('datatables', {
    template: "#datables",
    props: ['parent_url', 'data', 'tabindex','reflushtbl'],
    data: function () {
        if (this.data == 'jlr') {
            return {
                id: "jlr",
                time: {
                    last_one: '',
                    last_two: '',
                    last_three: '',
                },
                stock_url: '/api/stock/jlr',
                table: {
                    stock_url: '/api/stock/jlr',
                    columns: [{
                        "data": null,
                        'orderable': false
                    }, {
                        "data": "cpy_id"
                    }, {
                        "data": "name"
                    }, {
                        "data": "zlbfb"
                    }, {
                        "data": "jlr"
                    }, {
                        "data": "two"
                    }, {
                        "data": "one"
                    }, {
                        "data": "calc"
                    }, {
                        "data": "three"
                    }, {
                        "data": "zf"
                    }, {
                        "data": "zs"
                    }, {
                        "data": null,
                        'orderable': false
                    }],
                    current: null
                }
            };
        } else if (this.data == 'ddx') {
            return {
                id: "ddx",
                time: {
                    last_one: '',
                    last_two: '',
                    last_three: '',
                },
                stock_url: '/api/stock/ddx',
                table: {
                    stock_url: '/api/stock/ddx',
                    columns: [{
                            "data": null,
                            'orderable': false
                        }, {
                            "data": "cpy_id"
                        }, {
                            "data": "name"
                        },
                        {
                            'data': 'zlbfb'
                        },
                        {
                            "data": 'zljb'
                        },
                        {
                            'data': 'two'
                        },
                        {
                            "data": "one"
                        }, {
                            "data": "lst_ddxCache"
                        }, {
                            "data": "three"
                        }, {
                            "data": "zf"
                        }, {
                            "data": "zs"
                        }, {
                            'data': null,
                            'orderable': false
                        }
                    ],
                    current: null
                }
            };
        } else {
            return {
                id: "nszl",
                time: {
                    last_one: '',
                    last_two: '',
                    last_three: '',
                },
                stock_url: '/api/stock/nszl',
                table: {
                    stock_url: '/api/stock/nszl',
                    columns: [{
                        "data": null,
                        'orderable': false
                    }, {
                        "data": "cpy_id"
                    }, {
                        "data": "name"
                    }, {
                        "data": 'nxjlrjh'
                    }, {
                        "data": "nxjlrch"
                    }, {
                        "data": "nxjlr"
                    }, {
                        "data": "jhcs"
                    }, {
                        "data": "chcs"
                    }, {
                        "data": "jcc"
                    }, {
                        "data": "zf"
                    }, {
                        "data": "zs"
                    }, {
                        'data': null,
                        'orderable': false
                    }],
                    current: null
                }
            };
        }
    },
    mounted: function () {
        this.time.last_one = getTime(1);
        this.time.last_two = getTime(2);
        this.time.last_three = getTime(3);
        if (this.tabindex == 0 && this.data == 'jlr') {
            this.handle();
        }

    },
    methods: {
        handle: function () {
            if (typeof this.table.current === undefined || this.table.current == null) {
                this.table.current = $('#' + this.id).DataTable(build_datables(this.table));
                return true;
            }
             if (this.tabindex == 0 && this.data == 'jlr') {
                 this.table.current.ajax.reload();
            } else if (this.tabindex == 1 && this.data == 'ddx') {
                 this.table.current.ajax.reload();
            } else if (this.tabindex == 2 && this.data == 'nszl') {
                 this.table.current.ajax.reload();
            }
        },
         reflushTime: function () {
                this.time.last_one = getTime(1);
                this.time.last_two = getTime(2);
                this.time.last_three = getTime(3);
        }
        
    },
    watch: {
        parent_url: function () {
            this.table.stock_url = this.stock_url + this.parent_url;
          
                this.handle();
        
           
           
        },
        reflushtbl:function(){
             if (this.tabindex == 0 && this.data == 'jlr') {
                this.handle()
            } else if (this.tabindex == 1 && this.data == 'ddx') {
                this.handle();
            } else if (this.tabindex == 2 && this.data == 'nszl') {
                this.handle();
            }
            this.reflushTime();
        },
        tabindex: function () {
            if (this.tabindex == 0 && this.data == 'jlr') {
                this.handle()
            } else if (this.tabindex == 1 && this.data == 'ddx') {
                this.handle();
            } else if (this.tabindex == 2 && this.data == 'nszl') {
                this.handle();
            }


        }
    }
});






try {
        var mincount = 0;
        inteval = setInterval(function () {
            var d = new Date();
            var h = d.getHours();
            var m = d.getMinutes();
            if (h < 9) {
                clearInterval(inteval);
            }
            if (h == 12) {
                clearInterval(inteval);
                return;
            }
            if ((h >= 15 && m > 0)) {
                clearInterval(inteval);
                return;
            }
            mincount ++ ;
            layui.element().progress('demo', ((mincount /60 ) *100).toFixed(0) +'%');
            if(mincount >= 60){
                mincount = 0;
                app.$data.reflushTable = ! app.$data.reflushTable ;
              
            }
            
        }, 1000);
    
} catch (e) {

}