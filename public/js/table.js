$(function () {

    var inteval = null;

        Vue.component('datatables', {
        template: "#datables",
        props: ['parent_url', 'data', 'tabindex'],
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
                            "data": "calc"
                        }, {
                            "data": "one"
                        }, {
                            "data": "two"
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
                                'data': 'lst_ddxCache'
                            },
                            {
                                "data": "one"
                            }, {
                                "data": "two"
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
                console.log(this.table.current);
                if (typeof this.table.current === undefined || this.table.current == null) {
                    console.log('初始化');
                    this.table.current = $('#' + this.id).DataTable(build_datables(this.table));
                    return true;
                }
                return false;
            }
        },
        watch: {
            parent_url: function () {
                this.table.stock_url = this.stock_url + this.parent_url;
                if (this.table.current == null) {
                    return this.handle();
                }
                this.table.current.ajax.reload();
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