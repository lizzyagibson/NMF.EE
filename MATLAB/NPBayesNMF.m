function [EWA, EH, EA] = NPBayesNMF(X,Kinit,num_iter)
% X is the data matrix of non-negative values
% Kinit is the maximum allowable factorization (initial). The algorithm tries to reduce this number.
%       the size of EWA and EH indicate the learned factorization.
% EWA and EH are the left and right matrices of the factorization. Technically, they're the expected
%           values of these matrices according to their approximate posterior variational distributions.
% num_iter is the number of iterations to run. The code doesn't terminate based on convergence currently.

bnp_switch = 1;  % this turns on/off the Bayesian nonparametric part. I made the default off for now.

[dim,N] = size(X);

h01 = 1/Kinit; % ###This was \gamma constant in Hotlzman, also <1, but topic-specific?###
h02 = 1;

w01 = 1; %1/dim; ###Changed this prior to correspond with Holtzman paper###
w02 = 1;
W1 = gamrnd(dim*ones(dim,Kinit),1/dim);
% gamrnd(A,B) generates random numbers from the gamma distribution 
% with shape parameters in A and scale parameters in B.
W2 = dim*ones(dim,Kinit);

a01 = bnp_switch*1/Kinit + (1-bnp_switch);
a02 = 1;
A1 = a01 + bnp_switch*1000*ones(1,Kinit)/Kinit;
A2 = a02 + bnp_switch*1000*ones(1,Kinit);

H1 = ones(Kinit,N);
H2 = ones(Kinit,N);
% initializing variables

K = Kinit;
loss = zeros(num_iter, 1);

for iter = 1:num_iter
  
    EW = W1./W2;
    % element-wise multiplication
    % this is the expectation of W
    X_reshape = repmat(reshape(X',[1 N dim]),[K 1 1]);
    % B = repmat(A,n) returns an array containing n copies of A in the row and 
    % column dimensions. The size of B is size(A)*n when A is a matrix.
    % Transpose X and repeat it k times as tensor.

    ElnWA = psi(W1) - log(W2) + repmat(psi(A1)-log(A2),dim,1);
    ElnWA_reshape = repmat(reshape(ElnWA',[K 1 dim]),[1 N 1]);
    t1 = max(ElnWA_reshape,[],1);
    ElnWA_reshape = ElnWA_reshape - repmat(t1,[K 1 1]);
    % Expected value of log W * expected value of log A
    % why subtract t1?

    ElnH = psi(H1) - log(H2);
    % expected value of log H

    P = bsxfun(@plus,ElnWA_reshape,ElnH);
    P = exp(P);
    P = bsxfun(@rdivide,P,sum(P,1));
    % P is a probability to put a lower bound on the ELBO
    % expected value of log WAH is concave
    % include P to make expectation tractable

    % These are update steps from optimizing the ELBO 
    % take the gradient with respect to parameter, set to zero, solve
    H1 = h01 + sum(P.*X_reshape,3);
    H2 = h02 + repmat(sum(EW.*repmat(A1./A2,dim,1),1),N,1)';
    
    W1 = w01 + reshape(sum(X_reshape.*P,2),[K dim])';
    W2 = w02 + repmat(sum((H1./H2).*repmat((A1./A2)',1,N),2)',dim,1);
    
    A1 = a01 + bnp_switch*sum(sum(X_reshape.*P,3),2)';
    A2 = a02 + bnp_switch*sum(W1./W2,1).*sum(H1./H2,2)'; 
    
    % This is the sparse prior on A, pushing A to zero
    idx_prune = find(A1./A2 < 10^-3);
    if length(idx_prune) > 0
      W1(:,idx_prune) = [];
      W2(:,idx_prune) = [];
      A1(idx_prune) = [];
      A2(idx_prune) = [];
      H1(idx_prune,:) = [];
      H2(idx_prune,:) = [];
    end
    K = length(A1);
    
    loss(iter) = sum(sum(abs(X-(W1./W2)*diag(A1./A2)*(H1./H2))));
    
%    stem(A1./A2); colorbar; pause(.5);
    disp([num2str(iter) ' : ' num2str(sum(sum(abs(X-(W1./W2)*diag(A1./A2)*(H1./H2)))))]);

 if iter ~= 1 && abs(loss(iter-1)-loss(iter)) < 1e-3
        break % Added convergence criteria, ok?
  end
end

EA = A1./A2;
EWA = (W1./W2)*diag(A1./A2);
EH = H1./H2;
% expected values of WA and H are alpha/beta of the Gamma dist


