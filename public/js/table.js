$(function () {

    var inteval = null;






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