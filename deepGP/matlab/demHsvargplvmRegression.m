% DEMHSVARGPLVMREGRESSION A script to run deep GP regression.
%
% This is a generic demo. You can replace the data used here with your own
% data and run it (ie Ytr{1} has to be the observed data and inpX has to be
% your observed labels).
%
% To configure the deepGP used here, do the following:
%   1. If any of the fields you want to change appear in this demo in the
%   "configuring the deep gp" section, they change it directly there.
%   2. If the field you're looking for is not there, then check the available
%    configuration options in hsvargplvm_init.m. The way this works, is that
%    you just need to overwrite the corresponding workspace variables.
%    e.g. if in hsvargplvm_init.m you see a field "fixInducing", you can
%    overwrite this field by just calling this demo as:
%    >> fixInducing = true; demHsvargplvmClassification
%   3. If the field you're looking for is not in hsvargplvm_init.m, then
%   check (in this order) svargplvm_init.m and vargplvm_init.m, again
%   overwritting the configuration by specifying the variable to exist, as
%   above.
%    
% SEEALSO: demHsvargplvmClassification.m
%
% COPYRIGHT: Andreas Damianou, 2014
% DEEPGP

%% ------ CONFIGURING THE DEEP GP
%--- Mandatory configurations
if ~exist('Ytr', 'var'), error('You need to specify your outputs in Ytr{1}=...'); end
if ~exist('inpX', 'var'), error('You need to specify your inputs in inpX=...'); end

%--- Optional configurations: Whatever configuration variable is not already set (ie does not exist
% as a variable in the workspace) is set to a default value.
if ~exist('experimentNo'), experimentNo = 404; end
if ~exist('K'), K = 30; end
if ~exist('Q'), Q = 6; end
if ~exist('baseKern'), baseKern = 'rbfardjit'; end % {'rbfard2','white','bias'}; end
% This is called "dynamics" and "time" for historical reasons.. It actually refers to a coupling GP in the uppermost level
if ~exist('dynamicsConstrainType'), dynamicsConstrainType = {'time'}; end
stackedOpt = [];
if exist('stackedInitVardistIters', 'var'), stackedOpt.stackedInitVardistIters=stackedInitVardistIters; end
if exist('stackedInitIters', 'var'), stackedOpt.stackedInitIters=stackedInitIters; end
if exist('stackedInitSNR', 'var'), stackedOpt.stackedInitSNR=stackedInitSNR; end
if exist('stackedInitK', 'var'), stackedOpt.stackedInitK=stackedInitK; end
if ~exist('initXOptions', 'var'), initXOptions = []; end

% Initialise script based on the above variables. This returns a struct
% "globalOpt" which contains all configuration options
hsvargplvm_init;

% Automatically calibrate initial variational covariances - better to not change that
globalOpt.vardistCovarsMult = [];

[options, optionsDyn] = hsvargplvmOptions(globalOpt, inpX);

%% ------------- Initialisation and model creation
% Initialise latent spaces, unless the user already did that
if ~(iscell(options.initX) && prod(size(options.initX{1})) > 1)
    [globalOpt, options, optionsDyn, initXOptions] = hsvargplvmRegressionInitX(globalOpt, options, optionsDyn, inpX, Ytr, stackedOpt);
end


% Create the deep GP based on the model options, global options
% (configuration) and options for initialising the latent spaces X
model = hsvargplvmModelCreate(Ytr, options, globalOpt, initXOptions);

% Since we do regression, we need to add a GP on the parent node. This GP
% couples the inputs and is parametrised by options in a struct "optionsDyn".
model = hsvargplvmAddParentPrior(model, globalOpt, optionsDyn);


%-- We have the option to not learn the inducing points and/or fix them to
% the given inputs.
% Learn inducing points? (that's different to fixInducing, ie tie them
% to X's, if learnInducing is false they will stay in their original
% values, ie they won't constitute parameters of the model).
if exist('learnInducing') && ~learnInducing
    model = hsvargplvmPropagateField(model, 'learnInducing', false);
end
%--

if globalOpt.fixInducing && globalOpt.fixInducing
    model = hsvargplvmPropagateField(model, 'fixInducing', true);
    for m=1:model.layer{end}.M % Not implemented yet for parent node
        model.layer{end}.comp{m}.fixInducing = false;
    end
end


%!!!!!!!!!!!!!!!!!!!!!!!!-----------------------
if exist('DEBUG_entropy','var') && DEBUG_entropy
    model.DEBUG_entropy = true;for itmp=1:model.H, model.layer{itmp}.DEBUG_entropy = true; end
end
        
params = hsvargplvmExtractParam(model);
model = hsvargplvmExpandParam(model, params);
model.globalOpt = globalOpt;
% Computations can be made in parallel, if option is activated
model.parallel = globalOpt.enableParallelism;

fprintf('# Scales after init. latent space:\n')
hsvargplvmShowScales(model,false);
%% OPTIMISATION
[model,modelPruned, modelInitVardist] = hsvargplvmOptimiseModel(model, true, true);

% If you decide to train for further iterations...
% modelOld = model; [model,modelPruned, ~] = hsvargplvmOptimiseModel(model, true, true, [], {0, [100]});


