var todos = [{label: "hello",      complete: true },
             {label: "from",       complete: false},
             {label: "JavaScript", complete: true },
             {label: "more",       complete: false},
             {label: "items",      complete: false}];

var editing = {value: ""};


function main() {
    if(ui.begin_window("Todo window!", 50, 10, 300, 400)) {
        ui.layout_row(-1,-25);
        ui.begin_panel("Todo list");
        ui.layout_begin_column();
        for(const [i, {label, complete}] of todos.entries()) {
            todos[i].complete = ui.checkbox(label,complete);
        }
        ui.layout_end_column();
        ui.end_panel();

        ui.layout_row(-70, -1, 20);
        ui.textbox(editing);
        if(ui.button("Add") || editing.submit) {
            todos.push({label: editing.value, complete: false});
            editing.value = "";
            ui.log(`added todo: ${editing.value}`);
        }


        ui.end_window();
    }

    if(ui.begin_window("Actions", 400, 10, 120, 75)) {
        ui.layout_row(100, 20);
        if(ui.button("Clear completed!")) {
            todos = todos.filter(t => !t.complete);
        }
        ui.end_window();
    }



}


const win_defaults = {title: "Untitled window!",
                      x: 1, y: 1, w: 150, h: 150};

function win(opts, body) {
    const {title,x,y,w,h} = {...win_defaults, ...opts};
    if(ui.begin_window(title, x,y,w,h)) {
        body();
        ui.end_window();
    }
}

function stats() {
    win({title: "Stats", x: 400, y: 100}, ()=>{
        var completed = 0;
        var todo = 0;
        var all = 0;
        for(const {complete} of todos) {
            all += 1;
            if(complete) completed += 1;
            else todo += 1;
        }

        ui.layout_row(90, 40, 20);
        ui.label("Complete");
        ui.label(`${completed}`);

        ui.label("Todo");
        ui.label(`${todo}`);

        ui.label("ALL");
        ui.label(`${all}`);

    });
}



















var evals = [];
var eval_editing = {value: ""};
function repl() {
    win({title: "Console", x:200,y:420,w:600,h:180}, _=>{
        ui.layout_row(-1,-25);
        ui.begin_panel("Consol");
        ui.layout_begin_column();
        for(const {src,result} of evals) {
            ui.label(`${src} => ${result}`);
        }

        ui.layout_end_column();
        ui.end_panel();

        ui.layout_row(590, 25);
        ui.textbox(eval_editing);
        if(eval_editing.submit) {
            const src = eval_editing.value;
            var result;
            try {
                result = eval(src);
            } catch(e) {
                result = `ERROR: ${e}`;
            }
            evals.push({src: src, result: result});
            eval_editing.value = "";
        }


    });


}
