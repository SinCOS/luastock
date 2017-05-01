$(function () {

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
    table_info.current = $("#table_one").DataTable({
        "aaSorting": [
            [8, "desc"]
        ],
        "oLanguage": Language,

        "processing": true, //载入数据的时候是否显示“载入中”
        "serverSide": true, //生成get数据
        "columns": table_info.columns,
        "fnServerData": function (sSource, aoData, fnCallback) {
            console.log(table_info.stock_url);
            $.ajax({
                    url: table_info.stock_url,
                    type: 'GET',
                    dataType: 'json',
                    data: jsk(aoData),
                })
                .done(function (resp) {
                    fnCallback(resp);
                })
                .fail(function () {

                    layer.msg('获取数据失败');
                })
                .always(function () {
                    console.log("complete");
                });


        },
        "fnRowCallback": function (nRow, aData, iDisplayIndex) {
            var page = table_info.current.page();
            var page_len = table_info.current.page.len();
            $('td:eq(0)', nRow).text(page * page_len + iDisplayIndex + 1);
            var $object = null;;
           
            $object = $('td:eq(11)',nRow);
            
            $object.addClass('cpy_id').attr('data', aData['cpy_id']).on('click', function () {
                var self = this;
                var cpy_id = $(this).attr('data');
                var cpy_name = $(this).attr("cpy_name");
                var _title = $(self).text();
                if (_title == '取消关注') {
                    Vue.http.delete('/user/favor/' + app.$data.favorselectIndex + '/' + cpy_id).then(function ($resp) {
                        layer.msg($resp.body.message)
                        if ($resp.body.status == 200) {
                            setTimeout(function () {
                                table_info.current.ajax.reload();
                            }, 2000);
                        }
                    }).catch(function ($resp) {
                        alert("删除失败");
                    });

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
                "cursor":'pointer'});;
            if (parseFloat(aData['zf']) > 0) {
                $('td:eq(9)', nRow).addClass('error');
                aData['zf'] = '+' + aData['zf'];
                $('td:eq(9)',nRow).text(aData['zf'])
                console.log(aData['zf']);
            }else if(parseFloat(aData['zf']) < 0 ){
                $('td:eq(9)',nRow).addClass('success');
            }
            return nRow;
        }
    });


    try {

        if (typeof table_info !== undefined && table_info.current) {
            console.log('ok');
            inteval = setInterval(function () {
                var d = new Date();
                var h = d.getHours();
                var m = d.getMinutes();
                if (h < 9) {
                    clearInterval(inteval);
                }
                if (!(h == 11 && m <= 30)) {
                    clearInterval(inteval);
                    return;
                }
                if (h == 12) {
                    clearInterval(inteval);
                    return;
                }
                if ((h >= 15 && m > 0)) {
                    clearInterval(inteval);
                    return;
                }
                app.reflushTime();
                table_info.current.ajax.reload();
            }, 30 * 1000);
        }
    } catch (e) {

    }


});