clear all;
close all;%clc
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
%% Setup Matlab path.
setupSRToolbox;
iat_setup;
PSNR=[];SSIM=[];iframe=0;
%% Load low-resolution frames
 frame=8;
nameImg=[4,5,7,9];
nameNoise=[0.02,0.06,0.1];
 for iname=1:length(nameImg)
    for jnoise=1:length(nameNoise)
pathname=['simulation data\',...
                num2str(nameNoise(jnoise)),'Gaussian\',num2str(nameImg(iname),'%02d'),'_0.2psf_LRImages_'...
                ,num2str(nameNoise(jnoise)),'gaussian_100frame.mat'];
            load(pathname);
LRImages=LRImages(:,:,1:frame);imgNumber = size(LRImages,3);
%% High-resolution image
ref0=imread(['Set12\',num2str(nameImg(iname),'%02d'),'.png']);
ref0=double(ref0(:,:,1));
ref0=ref0./max(ref0(:));
%%
% Setup super-resolution model parameters
model = SRModel;
model.magFactor = 2;
model.psfWidth = 0.2;%model.comfidence=1;
transform = 'translation';
refFrame = 1;
%%
% Motion estimation for individual low-resolution frames.
if isempty(model.motionParams)
    % Set parameters for ECC registration algorithm.% Entropy Corrleation Coefficient,ECC 
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
%         model.confidence{m}=imageToVector(ones(12,12));
    end
    model.motionParams = motionParams;
%     end
end
%% set parameters for Super-Resolution of the LRImages
% Setup weighted bilateral total variation prior.
model.imagePrior = SRPrior('function', @btvPriorWeighted, 'gradient', @btvPriorWeighted_grad, 'weight', [], 'parameters', {model.magFactor * size(LRImages(:,:,1)), 2, 0.5, []});

%% SR 
reweightedOptimParams = getReweightedOptimizationParams;
tic
[SR_irwsr, model_irwsr, report] = superresolve(LRImages, model, ...
    'reweightedSR', reweightedOptimParams,1,ref0);
% 'ARPT' should be replaced by 'GCV' if GCV algorithm is applied
% "ref0" is the reference image. "ref0" should be added when PSNR and SSIM need to be calculated 
toc
savepath=['\report_',...
    num2str(nameImg(iname),'%02d'),'_',num2str(nameNoise(jnoise)),'1.mat'];
tempLR=imresize(LRImages(:,:,1),2);
H = iat_ecc(tempLR, ref0, eccParams);
tempLR=imtranslate(tempLR,-[H(1),H(2)]);

[psnr0, snr0] = psnr(ref0(11:end-10,11:end-10),tempLR(11:end-10,11:end-10) );
ssim0 = ssim(tempLR(11:end-10,11:end-10),ref0(11:end-10,11:end-10));

report.psnr=[psnr0,report.psnr];
report.ssim=[ssim0,report.ssim];
report.time=[0,report.time];
save(savepath,'report')
figure,imshow(SR_irwsr);
    end
 end

%% calculate the PSNR
[peaksnr, snr] = psnr(ref0(11:end-10,11:end-10),SR_irwsr(11:end-10,11:end-10) )
ssim_index = ssim(SR_irwsr(11:end-10,11:end-10),ref0(11:end-10,11:end-10))


