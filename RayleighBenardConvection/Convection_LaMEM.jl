using GLMakie
using GeophysicalModelGenerator, Statistics

Makie.inline!(true)


include("../src/widgets.jl")
include("../src/Basic_LaMEM_GUI.jl")

clean_directory()

# Define the simulation name & the output files: 
ParamFile  = "Convection.dat"
OutFile    = "Convection"
resolution = primary_resolution()
width =  round(Int,resolution[1]/11);

if Sys.isapple()
    resolution = (2500,1500)
    
    fontsize   = 30
else
 #   resolution = (1200,800)
    fontsize   = 20
end
#width=160;

# Create Basic GUI
fig, ax, gui = Create_Basic_LaMEM_GUI(OutFile, ParamFile, resolution=resolution, fontsize=fontsize, width=width, colormap=Reverse(:roma),
                    size_total=(1:21, 1:7), size_ax=(2:20, 2:4));
ax.title =  ""
gui.menu.i_selected=2       # T
gui.menu.selection="temperature"

# add left plot
ax_T   = Axis(fig[2:20,1], xlabel="T[C]", ylabel="Depth[km]")
ax_Vel = Axis(fig[2,2:5], title="Rayleigh Benard Convection", ylabel="Vx[cm/yr]", xlabel="Width[km]")


# Add textboxes:
Height,_   = Textbox_with_label_left(fig[6, 6:7], L"\mathrm{Height [km]}", "1000", width=width);
AspectR,_ = Textbox_with_label_left(fig[7, 6:7], L"\mathrm{AspectRatio}", "2", width=width);
Tbot,_ = Textbox_with_label_left(fig[8, 6:7], L"T_\mathrm{bottom} [^o\mathrm{C}]", "2000", width=width);
Yield,_ = Textbox_with_label_left(fig[9, 6:7], L"\mathrm{YieldStress[MPa]}", "500", width=width);

# Add sliders:
gamma_sl, _, _ = Slider_with_text_above(fig[10:11,6:7], L"\eta=\eta_\mathrm{0}\exp\left(-\gamma T \right), \hspace \gamma=", 0:.001:.01, 1e-9);
eta_sl, _, _ = Slider_with_text_above(fig[12:13,6:7], L"\log_{10}(\eta_{\mathrm{0}} \mathrm{  [Pas]})", 15:.25:25, 21);

# Add toggle:
temp_toggle,_ = Toggle_with_label_left(fig[18, 6:7], "Temperature isocontours", true);


# Create setup with random noise
function CreateSetup(ParamFile, ΔT=1000, ampl_noise=100 ; args)
    Grid        =   ReadLaMEM_InputFile(ParamFile, args=args)
    Phases      =   zeros(Int64, size(Grid.X));      
    Temp        =   ones(Float64,size(Grid.X))*ΔT/2 ;     
    Temp        =   Temp + rand(size(Temp)...).*ampl_noise
    Phases[Grid.Z.>0.0] .= 1
    Temp[Grid.Z.>0.0] .= 0.0
    
    Model3D     =   CartData(Grid, (Phases=Phases,Temp=Temp))   # Create LaMEM model
    Write_Paraview(Model3D,"LaMEM_ModelSetup", verbose=false)   # Save model to paraview   (load with opening LaMEM_ModelSetup.vts in paraview)  

    Save_LaMEMMarkersParallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end


# Update plot info to include contours
function update_plot_info(OutFile, gui::NamedTuple, t_step::Int64; last=false)
        
    t_step, data = update_plot_info_basic(OutFile, gui, t_step; last=last)
    
    ifield = findall(contains.(gui.menu.options[],"temperature"))[]
    x,z = data.x.val[:,1,1], data.z.val[1,1,:];
    T_field = Read_data_field(ifield, data, 1)

    ifield = findall(contains.(gui.menu.options[],"velocity"))[]
    Vx_field = Read_data_field(ifield, data, 1)
    
    temp_toggle.active[] ?    iso_con = true :   iso_con = false

    # optionally plot isocontours for T
    if isa(ax.scene.plots[end], Combined{Makie.contour, Tuple{Vector{Float32}, Vector{Float32}, Matrix{Float32}}})
        delete!(ax.scene,ax.scene.plots[end])
    end
    if iso_con
        contour!(ax, x,z,T_field, levels=20, color=:black)
    end

    # Average T
    if length(ax_T.scene.plots)>0
        delete!(ax_T.scene,ax_T.scene.plots[end])
    end
    lines!(ax_T,mean(T_field, dims=1)[:],z, color=:blue)
    ylims!(ax_T,minimum(z),0)

    # Top Vx
    if length(ax_Vel.scene.plots)>0
        delete!(ax_Vel.scene,ax_Vel.scene.plots[end])
    end
    lines!(ax_Vel,x,Vx_field[:,end], color=:blue)
    xlims!(ax_Vel,minimum(x),maximum(x))

    return t_step, gui
end


# Run the LaMEM simulation (modify some parameters if you want) 
function run_code(ParamFile, gui; wait=true)

    nel_x,nel_z = retrieve_resolution(ParamFile, gui)

    # Retrieve various parameters from the GUI:
    H, AR, ΔT, nstep_max, σy = get_values_textboxes((Height,AspectR, Tbot, gui.nstep_max_tb, Yield))
    η0   =  10.0^eta_sl.value[]
    gam  = gamma_sl.value[]
    if gam==0.0
        gam = 1e-9
    end
    ch = σy*1e6     # cohesion (in Pa)

    W = H*AR;       # width
    nel_x = round(Int64,nel_z*AR)
    Δx = ceil(W/nel_x);   # spacing in x    

    # Retrieve some parameters from the GUI
    nstep_max_val = Int64(nstep_max)

    # command-line arguments
    #args = "-nstep_max $(nstep_max_val) -eta_fk[0] $η0  -gamma_fk[0] $gam -TRef_fk[0] $(ΔT/2) -ch[0] $ch -nel_x $nel_x -nel_z $nel_z -coord_x $(-W/2),$(W/2) -coord_z $(-H),$(H/10) -coord_y $(-Δx/2),$(Δx/2) -temp_bot $ΔT"
    args = "-nstep_max $(nstep_max_val) -eta_fk[0] $η0  -gamma_fk[0] $gam -TRef_fk[0] $(ΔT/2) -ch[0] $ch -nel_x $nel_x -nel_z $nel_z -coord_x $(-W/2),$(W/2) -coord_z $(-H),0 -coord_y $(-Δx/2),$(Δx/2) -temp_bot $ΔT"
    
    
    @show args
    # Create the setup
    CreateSetup(ParamFile, ΔT, args=args)
    @info "created marker setup"

    # Run LaMEM with these parameters
    run_lamem(ParamFile, 1, args, wait=wait)
    #run_lamem(ParamFile, 1, args) 
end