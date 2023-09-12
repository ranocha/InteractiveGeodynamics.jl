using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM


# this is the main figure window
function create_main_figure()
    fig =  dcc_graph(
        id = "example-graph-1",
        figure = (
            data = [
                (x = ["giraffes", "orangutans", "monkeys"], y = [20, 14, 23], type = "bar", name = "SF"),
                (x = ["giraffes", "orangutans", "monkeys"], y = [12, 18, 29], type = "bar", name = "Montreal"),
            ],
            layout = (title = "Dash Data Visualization", barmode="group")
        ),
        #animate   = false,
        #responsive=false,
        #clickData = true,
        #config = PlotConfig(displayModeBar=false, scrollZoom = false),
        style = attr(width="80vw", height="80vh",padding_left="0vw",)
        )
    return fig
end

function run_code(ParamFile; wait = true)

   #nel_x,nel_z = retrieve_resolution(ParamFile)

end

title_app = "Rising Sphere example"
ParamFile = "RisingSphere.dat"


#app = dash(external_stylesheets=[dbc_themes.CYBORG])
app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)

# Main code layout
app.layout = html_div() do
    dbc_container(className = "mxy-auto", fluid=true, [
        dbc_col(html_h1(title_app), style = Dict("margin-top" => 0, "textAlign" => "center")),
        
        dbc_row([
                dbc_col(create_main_figure())      # main figure window

                # right side menu
                dbc_col([   dbc_card([dbc_col(dbc_label("Time: 0Myrs", id="label-time")),
                                      dbc_col(dbc_label("Timestep: 0", id="label-timestep"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Density of Sphere", id="density_sphere_label")),
                                    dbc_col(dbc_input(id="sphere_density", placeholder="Type something...", type="text"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Density of Matrix", id="density_matrix_label")),
                                    dbc_col(dbc_input(id="matrix_density", placeholder="Type something...", type="text"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Radius of Sphere", id="sphere_radius_label")),
                                    dbc_col(dbc_input(id="sphere_radius", placeholder="Type something...", type="text"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Width of Domain", id="domain_width_label")),
                                    dbc_col(dbc_input(id="domain_width", placeholder="Type something...", type="text"))]),
                            dbc_col(dbc_button("RUN", id="button-run", size="lg")),
                                    ],

                            
                            width=2)
        
        ])

    ])
end


# Save state
callback!(app,
    Output("label-timestep", "children"), 
    Input("button-run", "n_clicks"),
    prevent_initial_call=true
) do n_run
    


    
    str = "$n_run"
    
    return str
end





run_server(app, debug=false)
