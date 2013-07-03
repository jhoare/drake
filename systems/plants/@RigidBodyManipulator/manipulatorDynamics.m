function [H,C,B,dH,dC,dB] = manipulatorDynamics(obj,q,qd,use_mex)

checkDirty(obj);

if (nargin<4) use_mex = true; end

m = obj.featherstone;

if length(obj.force)>0
  f_ext = sparse(6,m.NB);
  for i=1:length(obj.force)
    % compute spatial force should return something that is the same length
    % as the number of bodies in the manipulator
    force = computeSpatialForce(obj.force{i},obj,q,qd);
    f_ext(:,m.f_ext_map_to) = f_ext(:,m.f_ext_map_to)+force(:,m.f_ext_map_from);
  end
else
  f_ext=[];
end

if (use_mex && obj.mex_model_ptr~=0 && isnumeric(q) && isnumeric(qd))
  f_ext = full(f_ext);  % makes the mex implementation simpler (for now)
  if (nargout>3)
    if ~isempty(f_ext) error('not implemented yet'); end
    [H,C,dH,dC] = HandCmex(obj.mex_model_ptr,q,qd,f_ext);
    dH = [dH, zeros(m.NB*m.NB,m.NB)];
    dB = zeros(m.NB*obj.num_u,2*m.NB);
  else
    [H,C] = HandCmex(obj.mex_model_ptr,q,qd,f_ext);
  end
else  
  if (nargout>3)
    % featherstone's HandC with analytic gradients
    a_grav = [0;0;0;obj.gravity];
    
    S = cell(m.NB,1);
    Xup = cell(m.NB,1);
    
    v = cell(m.NB,1);
    avp = cell(m.NB,1);
    
    %Derivatives
    dXupdq = cell(m.NB,1);
    dvdq = cell(m.NB,1);  %dvdq{i,j} is d/dq(j) v{i}
    dvdqd = cell(m.NB,1);
    davpdq = cell(m.NB,1);
    davpdqd = cell(m.NB,1);
    fvp = cell(m.NB,1);
    dfvpdq = cell(m.NB,1);
    dfvpdqd = cell(m.NB,1);
    
    
    for i = 1:m.NB
      n = m.dofnum(i);
      
      dvdq{i} = zeros(6,m.NB)*q(1);
      dvdqd{i} = zeros(6,m.NB)*q(1);
      davpdq{i} = zeros(6,m.NB)*q(1);
      davpdqd{i} = zeros(6,m.NB)*q(1);
      dfvpdq{i} = zeros(6,m.NB)*q(1);
      dfvpdqd{i} = zeros(6,m.NB)*q(1);
      
      [ XJ, S{i} ] = jcalc( m.pitch(i), q(n) );
      dXJdq = djcalc(m.pitch(i), q(n));
      
      vJ = S{i}*qd(n);
      dvJdqd = S{i};
      
      Xup{i} = XJ * m.Xtree{i};
      dXupdq{i} = dXJdq * m.Xtree{i};
      
      if m.parent(i) == 0
        v{i} = vJ;
        dvdqd{i}(:,n) = dvJdqd;
        
        avp{i} = Xup{i} * -a_grav;
        davpdq{i}(:,n) = dXupdq{i} * -a_grav;
      else
        j = m.parent(i);

        v{i} = Xup{i}*v{j} + vJ;
        
        dvdq{i} = Xup{i}*dvdq{j};
        dvdq{i}(:,n) = dvdq{i}(:,n) + dXupdq{i}*v{j};
        
        dvdqd{i} = Xup{i}*dvdqd{j};
        dvdqd{i}(:,n) = dvdqd{i}(:,n) + dvJdqd;
        
        avp{i} = Xup{i}*avp{j} + crm(v{i})*vJ;
        
        davpdq{i} = Xup{i}*davpdq{j};
        davpdq{i}(:,n) = davpdq{i}(:,n) + dXupdq{i}*avp{j};
        for k=1:m.NB,
          davpdq{i}(:,k) = davpdq{i}(:,k) + ...
            dcrm(v{i},vJ,dvdq{i}(:,k),zeros(6,1));
        end
        
        dvJdqd_mat = zeros(6,m.NB);
        dvJdqd_mat(:,n) = dvJdqd;
        davpdqd{i} = Xup{i}*davpdqd{j} + dcrm(v{i},vJ,dvdqd{i},dvJdqd_mat);
      end
      fvp{i} = m.I{i}*avp{i} + crf(v{i})*m.I{i}*v{i};
      dfvpdq{i} = m.I{i}*davpdq{i} + dcrf(v{i},m.I{i}*v{i},dvdq{i},m.I{i}*dvdq{i});
      dfvpdqd{i} = m.I{i}*davpdqd{i} + dcrf(v{i},m.I{i}*v{i},dvdqd{i},m.I{i}*dvdqd{i});
      
      if ~isempty(f_ext)
        fvp{i} = fvp{i} - f_ext(:,i);
        error('need to implement f_ext gradients here');
      end
      
    end
    
    dC = zeros(m.NB,2*m.NB)*q(1);
    IC = m.I;				% composite inertia calculation
    dIC = cell(m.NB, m.NB);
    dIC = cellfun(@(a) zeros(6), dIC,'UniformOutput',false);
    
    for i = m.NB:-1:1
      n = m.dofnum(i);
      C(n,1) = S{i}' * fvp{i};
      dC(n,:) = S{i}'*[dfvpdq{i} dfvpdqd{i}];
      if m.parent(i) ~= 0
        fvp{m.parent(i)} = fvp{m.parent(i)} + Xup{i}'*fvp{i};
        dfvpdq{m.parent(i)} = dfvpdq{m.parent(i)} + Xup{i}'*dfvpdq{i};
        dfvpdq{m.parent(i)}(:,n) = dfvpdq{m.parent(i)}(:,n) + dXupdq{i}'*fvp{i};
        dfvpdqd{m.parent(i)} = dfvpdqd{m.parent(i)} + Xup{i}'*dfvpdqd{i};
        
        IC{m.parent(i)} = IC{m.parent(i)} + Xup{i}'*IC{i}*Xup{i};
        for k=1:m.NB,
          dIC{m.parent(i),k} = dIC{m.parent(i),k} + Xup{i}'*dIC{i,k}*Xup{i};
        end
        dIC{m.parent(i),i} = dIC{m.parent(i),i} + ...
          dXupdq{i}'*IC{i}*Xup{i} + Xup{i}'*IC{i}*dXupdq{i};
      end
    end
    
    % minor adjustment to make TaylorVar work better.
    %H = zeros(m.NB);
    H=zeros(m.NB)*q(1);
    
    %Derivatives wrt q(k)
    dH = zeros(m.NB^2,2*m.NB)*q(1);
    for k = 1:m.NB
      for i = 1:m.NB
        n = m.dofnum(i);
        fh = IC{i} * S{i};
        dfh = dIC{i,k} * S{i};  %dfh/dqk
        H(n,n) = S{i}' * fh;
        dH(n + (n-1)*m.NB,k) = S{i}' * dfh;
        j = i;
        while m.parent(j) > 0
          if j==k,
            dfh = Xup{j}' * dfh + dXupdq{k}' * fh;
          else
            dfh = Xup{j}' * dfh;
          end
          fh = Xup{j}' * fh;
          
          j = m.parent(j);
          np = m.dofnum(j);
          
          H(n,np) = S{j}' * fh;
          H(np,n) = H(n,np);
          dH(n + (np-1)*m.NB,k) = S{j}' * dfh;
          dH(np + (n-1)*m.NB,k) = dH(n + (np-1)*m.NB,k);
        end
      end
    end
    
    dH = dH(:,1:m.NB)*[eye(m.NB) zeros(m.NB)];
    dC(:,m.NB+1:end) = dC(:,m.NB+1:end) + diag(m.damping);
    dB = zeros(m.NB*obj.num_u,2*m.NB);
  else
    [H,C] = HandC(m,q,qd,f_ext,obj.gravity);
  end
  
  C=C+m.damping'.*qd;
end

B = obj.B;

end