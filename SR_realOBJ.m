clearvars;
close all;
clc
%% This code can realize the Iteratively Re-Weighted Minimization super-resolution 
% by GCV(general cross validation) and the adaptive regularization parameter
% tuning algorithm.
% The experimental data can be downloaded from the website 
% " https://pan.baidu.com/s/1F01ori_eGwytesCVup7SoQ ", "Password: ume9"
% The simulation data can be generated by the Matlab function 
%"generate_LRImages_batch.m" based on the Set12 datasets
%% The 1st vision of Matlab code is from the paper "T. Köhler, X. Huang,
% F. Schebesch, A. Aichert, A. K. Maier, and J. Hornegger, "Robust Multiframe 
% Super-Resolution Employing Iteratively Re-Weighted Minimization,
%" IEEE Transactions on Computational Imaging 2, 42-58 (2016)." 
% and modified by the author Feng Yang using ARPT method.
% please contact yangfeng2020@mail.tsinghua.edu.cn or clc@tsinghua.edu.cn
% if you have any questions
%% The use of this software is free for research purposes. 
% Please cite the papers associated with the different algorithms, 
% if you use them in your own work. The toolbox is provided for noncommercial 
% purposes only, without any warranty of merchantability or fitness for a
% particular purpose.
type='*.raw';
img_path='experimental data\';
img_dir = dir(fullfile(img_path, type));
img=[];
for i=1:18
filename = [img_path,img_dir(i).name];
id = fopen(filename,'r','b');
imgvector = fread(id,'uint16');
rows = 4096;
clos =4096;
temp = reshape(imgvector,[rows,clos]);
LRImages(:,:,i) = temp(1501:2000,3501:4000);
end 
imgNumber =18;%length(img_dir);% 18;
%%
setupSRToolbox;
model = SRModel;
model.magFactor = 2;
psf= 0.25;
model.psfWidth=psf;
transform = 'affine'; % 'translation','euclidean','affine','homography'
refFrame = imgNumber;%;

%%
% Motion estimation for individual low-resolution frames.
if isempty(model.motionParams)
    % Set parameters for ECC registration algorithm.
    eccParams.iterations = 30;
    eccParams.levels = 2;
    eccParams.transform = transform;
    for m = 1:size(LRImages, 3)
        
        if m == refFrame
            motionParams{m} = eye(3,3);
            continue;
        end
        
        % Pair-wise registration of the current frame to the reference.
        I = LRImages(:,:,refFrame);
        H = iat_ecc(LRImages(:,:,m), I, eccParams);
        
        % Assemble motion parameter structure.
        if strcmp(transform, 'translation')
            H = [1 0 H(1); 0 1 H(2); 0 0 1];
        else
            if size(H, 1) < 3
                H = [H; 0 0 1];
            end
        end
        motionParams{m} = inv(H);
    end
    model.motionParams = motionParams;
end

%% Super-resolution using iteratively re-weighted minimization.
% Setup weighted bilateral total variation prior.
model.imagePrior = SRPrior('function', @btvPriorWeighted, 'gradient', @btvPriorWeighted_grad, 'weight', [], 'parameters', {model.magFactor * size(LRImages(:,:,1)), 2, 0.5, []});
% Apply super-resolution
reweightedOptimParams = getReweightedOptimizationParams;
tic
[SR_irwsr, model_irwsr, report] = superresolve(LRImages, model,...
    'reweightedSR', reweightedOptimParams,1);
% 1 represents 'ARPT',0 represents 'GCV'
toc
SR_irwsr=SR_irwsr./max(SR_irwsr(:));
% figure; imshow(fliplr(SR_irwsr),[0.46,0.55]);
figure; imshow(fliplr(SR_irwsr),[]);
