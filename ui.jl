using Revise
using Unitful
using UnitlessFlatten
using OrdinaryDiffEq
using Photosynthesis
using DynamicEnergyBudgets
using InteractBulma, InteractBase, Blink, WebIO, Observables, CSSUtil
using Mux
using FieldMetadata
# using IterableTables, DataFrames, TypedTables
# using JLD2
# using Microclimate
using Plots
using UnitfulPlots
using PlotNested
# using StatPlots
import Plots:px, pct, GridLayout
import InteractBase: WidgetTheme, libraries
using DynamicEnergyBudgets: STATE, STATE1, TRANS, TRANS1, calc_scaling, define_organs, photosynthesis, split_state
using Profile

dir = "/home/raf/julia/DynamicEnergyBudgets/scratch/"
# dir = "/home/cloud"

# struct MyTheme <: WidgetTheme; end
# libraries(::MyTheme) = vcat(libraries(Bulma()), [joinpath(dir, "custom.css")])
# settheme!(MyTheme())
# gr()
plotly()
# pyplot()

const tspan = 0:1:10000
const statelabels = vcat([string("Shoot ", s) for s in STATE], [string("Root ", s) for s in STATE])

init_state(model) = init_state(model.params)
init_state(modelobs::Observable) = init_state(modelobs[].params)
init_state(::NTuple{2,ParamsCN}) = [0.0, 1e-4, 0.0, 1e-4, 1e-4, 1e-4, 0.0, 1e-4, 0.0, 10, 2, 0.0]
init_state(::NTuple{2,ParamsCNE}) = [0.0, 1e-4, 0.0, 1e-4, 1e-4, 1e-4, 0.0, 1e-4, 0.0, 1e-4, 1e-4, 10.0]
init_state(::NTuple{3,ParamsCN}) = [0.0, 1e-4, 0.0, 1e-4, 1e-4, 1e-4, 0.0, 1e-4, 0.0, 1e-4, 1e-4, 1e-4, 0.0, 1e-4, 0.0, 10, 10, 0.0]
init_state(::NTuple{3,ParamsCNE}) = [0.0, 1e-4, 0.0, 1e-4, 1e-4, 1e-4, 0.0, 1e-4, 0.0, 1e-4, 1e-4, 1e-4, 0.0, 1e-4, 0.0, 1e-4, 1e-4, 10.0]

photo(o, u, x) = begin
    update_photovars(o.vars.assimilation_vars, x)
    ustrip(photosynthesis(assimilation_pars(o), o, u))
end

update_photovars(v::CarbonVars, x) = v.J_L_F = x * oneunit(v.J_L_F)
update_photovars(v::Photosynthesis.PhotoVars, x) = v.par = x * oneunit(v.par)

function make_plot(model, varobs, stateobs, paramobs, fluxobs, tstop)
    # namedparams = AxisArray([params...], Axis{:parameters}(names))
    plotsize=(1700, 800)
    # try
        length(paramobs) > 0 || return plot()
        m = reconstruct(model, paramobs)
        organs = define_organs(m, 1)
        o = organs[1]
        u = stateobs
        state = split_state(organs, u, 0)
        dataplots = plot_selected(model, varobs, 1:tstop)
        prob = DiscreteProblem(m, u, (1, tstop))
        sol = solve(prob, FunctionMap(scale_by_time = true))
        solplot1 = plot(sol, vars = [1:6...], plotdensity=400, legend=:topleft, labels=reshape(statelabels[1:6], 1, 6), ylabel="State (CMol)",
                      xlabel=string(model.params[1].name, " : ",  typeof(model.params[1].assimilation_pars).name, " - time (hr)"))
        solplot2 = plot(sol, vars = [7:12...], plotdensity=400, legend=:topleft, labels=reshape(statelabels[7:12], 1, 6), ylabel="State (CMol)",
                      xlabel=string(model.params[2].name, " : ", typeof(model.params[2].assimilation_pars).name, " - time (hr)"))
        fluxplots = []
        if length(fluxobs) > 0
            plot_fluxes!(fluxplots, fluxobs[1], m.records[1].J, 1:tstop)
            plot_fluxes!(fluxplots, fluxobs[2], m.records[1].J1, 1:tstop)
            plot_fluxes!(fluxplots, fluxobs[3], m.records[2].J, 1:tstop)
            plot_fluxes!(fluxplots, fluxobs[4], m.records[2].J1, 1:tstop)
        end
        timeplots = plot(solplot1, solplot2, dataplots..., fluxplots..., layout=Plots.GridLayout(2+length(dataplots)+length(fluxplots), 1))

        # tempplot = plot(x -> ustrip(tempcorr(x * 1.0u"°C", m.shared.tempcorr)), 0.0:1.0:50.0, legend=false, ylabel="Correction", xlabel="°C")
        # scaleplots = plot_scaling.(m.params)
        # photoplot = plot(x -> photo(organs[1], state[1], x), 0:10:4000, ylabel="C uptake", xlabel="Irradiance")
        # funcplots = plot(tempplot, scaleplots..., photoplot, layout=Plots.GridLayout(2 + length(scaleplots), 1))

        l = Plots.GridLayout(1, 2)
        l[1, 1] = GridLayout(1, 1, width=0.8pct)
        l[1, 2] = GridLayout(1, 1, width=0.2pct)
        plot(timeplots, size=plotsize) #, layout=l, fmt = :png
    # catch err
        # plot(xlabel="model run failed", size=plotsize)
    # end
end

plot_scaling(p) = plot(x -> ustrip(calc_scaling(p.scaling_pars, x * 1.0u"mol")), 0.0:0.01:100.0,
                       legend=false, ylabel="Correction", xlabel="CMols Stucture")

plot_fluxes!(plots, obs, J, tspan) = begin
    ps = []
    labels = []
    Jstripped = ustrip(J)
    for y in 1:size(J, 1), x in 1:size(J, 2)
        if obs[y, x]
            push!(labels, "$y, $x")
            push!(ps, map(t -> Jstripped[y, x, t], tspan .+ 1))
        end
    end
    if length(ps) > 0
        push!(plots, plot(tspan, ps, labels=reshape(labels, 1, length(labels))))
    end
end

function spreadwidgets(widgets; cols = 7)
    vboxes = []
    widget_col = []
    colsize = ceil(Int, length(widgets)/cols)
    # Build vbox columns for widgets
    for i = 1:length(widgets)
        push!(widget_col, widgets[i])
        if rem(i, colsize) == 0
            push!(vboxes, vbox(widget_col...))
            widget_col = []
        end
    end
    # Push remaining widgets
    push!(vboxes, vbox(widget_col...))
    hbox(vboxes...)
end

allsubtypes(x) = begin
    st = subtypes(x)
    if length(st) > 0
        allsubtypes((st...,))
    else
        (x,)
    end
end
allsubtypes(t::Tuple{X,Vararg}) where X = (allsubtypes(t[1])..., allsubtypes(Base.tail(t))...,)
allsubtypes(::Tuple{}) = ()

build_model(params, rate, mat, rej, trans, scaling, allometry, assim1, assim2, temp, feedback, env) = begin
    pkwargs = (maturity_pars=mat(), rate_formula=rate(), rejection_pars=rej(), trans_pars=trans(),
              scaling_pars=scaling(), allometry_pars=allometry())
    p1 = params(;pkwargs..., assimilation_pars=assim1())
    p2 = params(;pkwargs..., assimilation_pars=assim2())
    sh = SharedParams(tempcorr_pars=temp(), feedback_pars=feedback())
    Organism(params=(p1, p2), shared=sh, environment=env, time=tspan,
             vars=(DynamicEnergyBudgets.ShootVars(), DynamicEnergyBudgets.RootVars()))
end

function muxapp(req) # an "App" takes a request, returns the output
    env = nothing #load_environment()
    emptyplot = plot()

    tstop = slider(20:9999, label="Timespan")
    reload = button("Reload")
    paramsdrop = dropdown([Nothing, allsubtypes(AbstractParams)...], label="Params")
    ratedrop = dropdown([Nothing, allsubtypes(AbstractRate)...], label="Rate")
    maturitydrop = dropdown([Nothing, allsubtypes(AbstractMaturity)...], label="Maturity")
    rejectiondrop = dropdown([Nothing, allsubtypes(AbstractRejection)...], label="Rejection")
    translocationdrop = dropdown([Nothing, allsubtypes(AbstractTranslocation)...], label="Translocation")
    scalingdrop = dropdown([Nothing, allsubtypes(AbstractScaling)...], label="Scaling")
    allometrydrop = dropdown([Nothing, allsubtypes(AbstractAllometry)...], label="Allometry")
    assimdrop1 = dropdown([Nothing, allsubtypes(AbstractAssim)...], label="Assimilation")
    assimdrop2 = dropdown([Nothing, allsubtypes(AbstractAssim)...], label="Assimilation")
    tempdrop = dropdown([Nothing, allsubtypes(AbstractTempCorr)...], label="Temp Correction")
    feedbackdrop = dropdown([Nothing, allsubtypes(AbstractStateFeedback)...], label="State Feedback")
    dropbox = vbox(hbox(tstop, reload, paramsdrop, ratedrop, maturitydrop, rejectiondrop, translocationdrop),
                   hbox(scalingdrop, allometrydrop, assimdrop1, assimdrop2, tempdrop, feedbackdrop))

    modelobs = Observable{Any}(DynamicEnergyBudgets.PlantCN(environment=env, time=tspan))
    map!(build_model, modelobs, throttle.(5, observe.((paramsdrop, ratedrop, maturitydrop, rejectiondrop, translocationdrop, scalingdrop,
                                                         allometrydrop, assimdrop1, assimdrop2, tempdrop, feedbackdrop)))..., env)
    on(observe(reload)) do x
        model = build_model(paramsdrop[], ratedrop[], maturitydrop[], rejectiondrop[], translocationdrop[], scalingdrop[],
                            allometrydrop[], assimdrop1[], assimdrop2[], tempdrop[], feedbackdrop[], env)
        params = flatten(model)
        for (i, p) in enumerate(paramsliders[])
            p[] = params[i]
        end
    end

    plt = Observable{typeof(emptyplot)}(emptyplot);

    paramsliders = Observable{Vector{Widget{:slider}}}(Widget{:slider}[]);
    paramobs = Observable{Vector{Float64}}(Float64[]);
    parambox = Observable{typeof(dom"div"())}(dom"div"());

    varchecks = Observable{Vector{Widget{:checkbox}}}(Widget{:checkbox}[]);
    varobs = Observable{Vector{Bool}}(Bool[]);
    varbox = Observable{typeof(dom"div"())}(dom"div"());

    statesliders = Observable{Vector{Widget{:slider}}}(Widget{:slider}[]);
    stateobs = Observable{Vector{Float64}}(init_state(modelobs[]));
    statebox = Observable{typeof(dom"div"())}(dom"div"());

    make_varchecks(m) = begin
        checks = plotchecks(m)
        map!((x...) -> [x...], varobs, observe.(checks)...)
        checks
    end

    make_paramsliders(m) = begin
        params = flatten(Vector, m)
        fnames = fieldnameflatten(Vector, m)
        parents = parentflatten(Vector, m)
        limits = metaflatten(Vector, m, DynamicEnergyBudgets.limits)
        descriptions = metaflatten(Vector, m, DynamicEnergyBudgets.description)
        attributes = broadcast((p, n, d) -> Dict(:title => "$p.$n: $d"), parents, fnames, descriptions)

        sl = broadcast((x,l,v,a) -> InteractBase.slider(x[1]:(x[2]-x[1])/100:x[2], label=string(l), value=v, attributes=a),
                       limits, fnames, params, attributes)
        map!((x...) -> [x...], paramobs, throttle.(0.2, observe.(sl))...)
        sl
    end

    make_statesliders(m) = begin
        sl = state_slider.(statelabels, init_state(m))
        map!((x...) -> [x...], stateobs, throttle.(0.2, observe.(sl))...)
        sl
    end

    flux_grids = (make_grid(STATE, TRANS), make_grid(STATE1, TRANS1,),
                  make_grid(STATE, TRANS), make_grid(STATE1, TRANS1));
    fluxbox = hbox(arrange_grid.(flux_grids)...)
    fluxobs = map((g...) -> g, observe_grid.(flux_grids)...)

    map!(make_varchecks, varchecks, modelobs)
    map!(make_statesliders, statesliders, modelobs)
    map!(make_paramsliders, paramsliders, modelobs)
    map!(make_plot, plt, modelobs, varobs, stateobs, paramobs, fluxobs, throttle(0.3, observe(tstop)))


    map!(c -> hbox(c...), varbox, varchecks)
    map!(s -> spreadwidgets(s), parambox, paramsliders)
    map!(s -> spreadwidgets(s), statebox, statesliders)

    modelobs[] = DynamicEnergyBudgets.Plant(time=tspan);
    observe(paramsliders[][5])[] = 0.45699

    # modelbox = hbox("Model: ", noenv, plantcne, plantcn, no_maturity, constantcn, constantcne, fvcbplant)
    ui = vbox(plt, dropbox, fluxbox, varbox, parambox, statebox);
end

state_slider(label, val) =
    slider(vcat(exp10.(range(-4, stop = 1, length = 100))), label=label, value=val)

make_grid(rownames, colnames) = begin
    rows = length(rownames)
    cols = length(colnames)
    [checkbox(false, label = join([string(rownames[r]), string(colnames[c])], ",")) for r = 1:rows, c = 1:cols]
end

arrange_grid(a) = hbox((vbox(a[:,col]...) for col in 1:size(a, 2))...)

observe_grid(a) = map((t...) -> [t[i + size(a,1) * (j - 1)] for i in 1:size(a,1), j in 1:size(a,2)], observe.(a)...)

using ProfileView
Profile.clear()

ui = muxapp(nothing)
w = Window(Dict("webPreferences"=>Dict("zoomFactor"=>0.6)));
Blink.AtomShell.@dot w webContents.setZoomFactor(0.6)
body!(w, ui);
# opentools(w)

# @profile for i in 1:10 make_plot(a, (true), flatten(a), (), 1000) end
# ProfileView.view()

# a(similar(u12), u12, nothing, 1)
# webio_serve(page("/", req -> muxapp(req)), 8000)

# function accordian(parambox)
#  dom"div"(
#   dom"section[class=accordions]"(
#       dom"article[class=accordion is-active]"(
#           dom"div[class=accordion-header toggle]"( "Sliders"),
#           dom"div[class=accordion-body]"(
#              dom"div[class=accordion-content]"(parambox))),
#       dom"article[class=accordion]"(
#           dom"div[class=accordion-header]"("Plots"),
#           dom"div[class=accordion-body]"(
#               dom"div[class=accordion-content]"(
#                  "content")))),
#     )
# end

# @ji w "var accordions = bulmaAccordion.attach();"
