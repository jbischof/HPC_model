# Global coordinate ascent algorithm

library("Matrix")

hpd.gibbs.sampler <- function(current.param.list,
                              #feature.count.list=NULL,
                              #doc.count.list=NULL,
                              topic.address.book=NULL,
                              ndraws.gibbs=1500,burnin=0,
                              Nupdate.hes=3,
                              verbose=FALSE,
                              print.iter=FALSE,debug=FALSE,
                              tree.job.list=NULL,xi.job.list=NULL,
                              file.current.param.list=NULL,
                              file.final.param.list=NULL,
                              file.ave.param.list=NULL,
                              tree.update=TRUE,xi.update=TRUE,
                              hparam.update=TRUE,
                              # Use case control sampling
                              # Regretfully ineffective
                              Ndoc.case.control=NULL,
                              Nfeat.case.control=NULL,
                              # Use less than all the documents for Gibbs sampler?
                              # (helpful to speed convergence)
                              frac.doc.use=NULL,
                              # For how many words and docs should record entire sample path?
                              nwords.trace=50,ndocs.trace=50,
                              ndraws.save=5,
                              # Should output computation times to file?
                              file.time=NULL
                              ){
  
  # Set up schedule for updating hessian
  hes.sched <- sqrt.seq.sched(1,ndraws.gibbs,Nupdate.hes)

  # Choose subset of documents to sample if requested
  if(!is.null(frac.doc.use)){
        xi.job.list <- pare.job.list(job.list=xi.job.list,frac.use=frac.doc.use)
        xi.updated <- unlist(xi.job.list)
   } else {xi.updated <- NULL}

  # Set up time recording file if requested
  if(!is.null(file.time)){
    cat(sprintf("%s\t%s\t%s\n","Compute","File I/O","Total"),file=file.time,
        append=FALSE)
  }
  
  # Create list of stored draws
  final.param.list <- setup.final.param.list(current.param.list=current.param.list,
                                             ndraws.gibbs=ndraws.gibbs,
                                             tree.update=tree.update,xi.update=xi.update,
                                             nwords.trace=nwords.trace,
                                             ndocs.trace=ndocs.trace)
  ave.param.list <- current.param.list
  
  # Send out signal to slaves to load up their data
  n.slaves <- mpi.comm.size(0)
  for(slave.id in 1:n.slaves){
    mpi.send.Robj(obj=0,dest=slave.id,tag=88,comm=0)}
  
  # Write out initial current.param.list
  save(current.param.list,file=file.current.param.list)
  
  # Cycle through blocks of draws
  for(i in 1:ndraws.gibbs){
    if(print.iter){cat(paste("\nGlobal iteration",i,"\n"))}
    t0 <- proc.time()[3]

    # Refresh the likelihood hessian if on first iteration or each 100 iters
    update.hessian.like <- i %in% hes.sched
    
    if(xi.update){
      # Cycle through all docs and draw membership parameters
      # Draw xis using MPI
      # Tell slave nodes to prepare to draw xis
      cat("Xi draws\n")
      master.param.fn(param.tag=6)
      xi.master.out <- xi.master.fn(xi.job.list=xi.job.list,
                                    xi.param.vecs=
                                    current.param.list$xi.param.vecs,
                                    theta.param.vecs=
                                    current.param.list$theta.param.vecs,
                                    update.hessian.like=update.hessian.like)
      # Maintain sparse representation of theta matrix
      current.param.list$theta.param.vecs <-
        as(xi.master.out$theta.param.vecs,"sparseMatrix")
      current.param.list$xi.param.vecs <- xi.master.out$xi.param.vecs
      if(tree.update){
        # Write out new current.param.list to pass along to tree update
        save(current.param.list,file=file.current.param.list)
      }
    }

    
    if(tree.update){
      # Cycle through all words and draw tree parameters
      # Draw tree parameters using MPI
      # Tell slave nodes to prepare to draw tree parameters
      cat("Tree draws\n")
      master.param.fn(param.tag=5)
      tree.master.out <- tree.master.fn(tree.job.list=tree.job.list,
                                        current.param.list=current.param.list,
                                        update.hessian.like=update.hessian.like)
      current.param.list <- tree.master.out
    }
    

    # Draw hyperameters
    if(hparam.update){
      hparam.outlist <- hparam.draw(current.param.list=current.param.list,
                                    tree.update=tree.update,xi.update=xi.update,
                                    frac.doc.use=frac.doc.use,xi.updated=xi.updated)
      
      if(tree.update){
        current.param.list$psi <- hparam.outlist$psi
        current.param.list$gamma <- hparam.outlist$gamma
        current.param.list$nu <- hparam.outlist$nu
        current.param.list$sigma2 <- hparam.outlist$sigma2
      }
      
      if(xi.update){
        current.param.list$eta.vec <- hparam.outlist$eta.vec
        if(current.param.list$full.Sigma){
          current.param.list$Sigma <- hparam.outlist$Sigma
          hparam.outlist$Sigma <- diag(hparam.outlist$Sigma)
        } else {current.param.list$lambda2 <- hparam.outlist$lambda2}
      }
      print(hparam.outlist)
      t1 <- proc.time()[3]
      if(verbose){cat(sprintf("Finished computation in %0.2f seconds\n",t1-t0))}
    }

    
    # Write out new current.param.list
    save(current.param.list,file=file.current.param.list)
    
    
    # Store the latest draws
    final.param.list <- store.param.draws(i=i,current.param.list=current.param.list,
                                          final.param.list=final.param.list,
                                          tree.update=tree.update,xi.update=xi.update)
    
    # Update desired expectations if after burnin period
    if(i > burnin){
      ave.param.list <- update.average.params(i=i-burnin,current.param.list=current.param.list,
                                              ave.param.list=ave.param.list,
                                              tree.update=tree.update,xi.update=xi.update,
                                              hparam.update=hparam.update)
    }
    
    # Write out new final.param.list and ave.param.list every ndraws.save draws
    if(i %% ndraws.save == 0){
      save(final.param.list,file=file.final.param.list)
      save(ave.param.list,file=file.ave.param.list)
    }
    
    t2 <- proc.time()[3]
    if(verbose){cat(sprintf("Finished file I/O in %0.2f seconds\n",t2-t1))}
    if(verbose){cat(sprintf("Total time: %0.2f\n",t2-t0))}
    if(all(!is.null(file.time),!update.hessian.like)){
    cat(sprintf("%0.2f\t%0.2f\t%0.2f\n",t1-t0,t2-t1,t2-t0),file=file.time,
        append=TRUE)
  }
  }
  
  
  # Tell worker nodes to exit
  master.exit.fn()
  
  # Return final set of parameters
  return(final.param.list)
}

#########################################################################
#########################################################################
# Function to space updates
# First try in sqrt space
# Want most points in the beginning, none at end
sqrt.seq.sched <- function(from,to,length.out){
  sqrt.sched <- seq(sqrt(from),sqrt(to),length.out=length.out+1)
  sched.raw <- (sqrt.sched[-(length.out+1)])^2
  sched <- trunc(sched.raw)
  return(sched)
}

seq.sched <- function(from,to,length.out){
  sched.raw <- seq(from,to,length.out=length.out+1)
  sched <- trunc(sched.raw[-(length.out+1)])
  return(sched)
}

#########################################################################
#########################################################################

# Function to pare down job list for faster initial updates

pare.job.list <- function(job.list,frac.use){

  # Check that frac.use between zero and one
  if(!all(frac.use<=1,frac.use>0)){stop("frac.use should be a number between zero and one.")}

  # Go through job list and keep frac.use jobs for each worker (round up)
  for (worker.id in names(job.list)) {
    worker.jobs <- job.list[[worker.id]]
    njobs <- length(worker.jobs)
    njobs.keep <- ceiling(njobs*frac.use)
    job.list[[worker.id]] <- sample(x=worker.jobs,size=njobs.keep,replace=FALSE)
  }

  return(job.list)
}



#########################################################################
#########################################################################

# Function to set up final.param.list
setup.final.param.list <- function(current.param.list,ndraws.gibbs,
                                   tree.update=TRUE,xi.update=TRUE,
                                   nwords.trace=NULL,ndocs.trace=NULL){
  K <- current.param.list$K
  D <- current.param.list$D
  V <- current.param.list$V
  nparents <- ncol(current.param.list$tau2.param.vecs)
  doc.names <- rownames(current.param.list$xi.param.vecs)
  parent.topic.names <- colnames(current.param.list$tau2.param.vecs)
  topic.names <- colnames(current.param.list$mu.param.vecs)
  word.names <- rownames(current.param.list$mu.param.vecs)
  
  final.param.list <- list()

  if(tree.update){
    if(!is.null(nwords.trace)){
      # Pick random sample of words to store if requested
      word.names.trace <- sample(x=word.names,size=nwords.trace,replace=FALSE)
    } else {
      nwords.trace <- V
      word.names.trace <- word.names
    }
    # Set up place to store tree parameters
    final.param.list$mu.corpus.vec <- matrix(NA,nrow=ndraws.gibbs,ncol=nwords.trace,
                                             dimnames=list(NULL,word.names.trace))
    final.param.list$mu.param.vecs <- array(NA,dim=c(nwords.trace,K,ndraws.gibbs),
                                            dimnames=list(word.names.trace,topic.names,NULL))
    final.param.list$tau2.param.vecs <- array(NA,dim=c(nwords.trace,nparents,ndraws.gibbs),
                                              dimnames=list(word.names.trace,parent.topic.names,NULL))
    final.param.list$psi <- rep(NA,ndraws.gibbs)
    final.param.list$gamma <- rep(NA,ndraws.gibbs)
    final.param.list$nu <- rep(NA,ndraws.gibbs)
    final.param.list$sigma2 <- rep(NA,ndraws.gibbs)
  }

  if(xi.update){
    # Set up place to store xi parameters
    # Pick random sample of docs to store if requested
    if(!is.null(ndocs.trace)){
      doc.names.trace <- sample(x=doc.names,size=ndocs.trace,replace=FALSE)
    } else {
      ndocs.trace <- D
      doc.names.trace <- doc.names
    }
    final.param.list$xi.param.vecs <- array(NA,dim=c(ndocs.trace,K,ndraws.gibbs),
                                            dimnames=list(doc.names.trace,topic.names,NULL))
    final.param.list$eta.vec <- matrix(NA,nrow=ndraws.gibbs,ncol=K,
                                       dimnames=list(NULL,topic.names))
    if(current.param.list$full.Sigma){
      final.param.list$Sigma <- array(NA,dim=c(K,K,ndraws.gibbs),
                                            dimnames=list(topic.names,topic.names,NULL))
    } else {final.param.list$lambda2 <- rep(NA,ndraws.gibbs)}
    
  }
  
  return(final.param.list)
}


store.param.draws <- function(i,current.param.list,final.param.list,
                              tree.update=TRUE,xi.update=TRUE){

  if(tree.update){
    # Store tree parameters
    words.trace <- colnames(final.param.list$mu.corpus.vec)
    final.param.list$mu.corpus.vec[i,] <- current.param.list$mu.corpus.vec[words.trace]
    final.param.list$mu.param.vecs[,,i] <- current.param.list$mu.param.vecs[words.trace,]
    final.param.list$tau2.param.vecs[,,i] <- current.param.list$tau2.param.vecs[words.trace,]
    final.param.list$psi[i] <- current.param.list$psi
    final.param.list$gamma[i] <- current.param.list$gamma
    final.param.list$nu[i] <- current.param.list$nu
    final.param.list$sigma2[i] <- current.param.list$sigma2
  }

  if(xi.update){
    # Store xi parameters
    docs.trace <- rownames(final.param.list$xi.param.vecs[,,1])
    final.param.list$xi.param.vecs[,,i] <- current.param.list$xi.param.vecs[docs.trace,]
    final.param.list$lambda2[i] <- current.param.list$lambda2
    final.param.list$eta.vec[i,] <- current.param.list$eta.vec

    if(current.param.list$full.Sigma){
      final.param.list$Sigma[,,i] <- current.param.list$Sigma
    } else {final.param.list$lambda2[i] <- current.param.list$lambda2}
  }
  
  return(final.param.list)
}


# Function to update posterior expectation of parameters
update.average.params <- function(i,current.param.list,ave.param.list,
                                  tree.update=TRUE,xi.update=TRUE,
                                  hparam.update=TRUE){

  # Get relative weights
  weight.current <- (i-1)/i
  weight.new <- 1/i
  
  if(tree.update){
    if(i==1){
      ave.param.list$mu.param.vecs <- current.param.list$mu.param.vecs
      ave.param.list$mu.corpus.vec <- current.param.list$mu.corpus.vec
      ave.param.list$tau2.param.vecs <- current.param.list$tau2.param.vecs
      if(hparam.update){
        ave.param.list$psi <- current.param.list$psi
        ave.param.list$gamma <- current.param.list$gamma
        ave.param.list$nu <- current.param.list$nu
        ave.param.list$sigma2 <- current.param.list$sigma2
      }
    } else {
      ave.param.list$mu.param.vecs <- weight.current*ave.param.list$mu.param.vecs +
        weight.new*current.param.list$mu.param.vecs
      ave.param.list$mu.corpus.vec <- weight.current*ave.param.list$mu.corpus.vec +
        weight.new*current.param.list$mu.corpus.vec
      ave.param.list$tau2.param.vecs <- weight.current*ave.param.list$tau2.param.vecs +
        weight.new*current.param.list$tau2.param.vecs
      if(hparam.update){
        ave.param.list$psi <- weight.current*ave.param.list$psi +
          weight.new*current.param.list$psi
        ave.param.list$gamma <- weight.current*ave.param.list$gamma +
          weight.new*current.param.list$gamma
        ave.param.list$nu <- weight.current*ave.param.list$nu +
          weight.new*current.param.list$nu
        ave.param.list$sigma2 <- weight.current*ave.param.list$sigma2 +
          weight.new*current.param.list$sigma2
      }
    }
    
    # Update phis
    phi.param.vecs <- get.phi.vec(mu.param.vecs=current.param.list$mu.param.vecs,
                                  parent.child.list=current.param.list$parent.child.list)
    phi.parent.param.vecs <- get.phi.parent.vec(mu.param.vecs=current.param.list$mu.param.vecs,
                                                mu.corpus.vec=current.param.list$mu.corpus.vec,
                                                parent.child.list=current.param.list$parent.child.list)
    phi.ave.param.vecs <- get.phi.ave.vec(phi.param.vecs=phi.param.vecs,
                                          phi.parent.param.vecs=phi.parent.param.vecs,
                                          parent.child.list=current.param.list$parent.child.list)
    if(i==1){
      ave.param.list$phi.param.vecs <- phi.param.vecs
      ave.param.list$phi.parent.param.vecs <- phi.parent.param.vecs
      ave.param.list$phi.ave.param.vecs <- phi.ave.param.vecs
    } else {
      ave.param.list$phi.param.vecs <- weight.current*ave.param.list$phi.param.vecs +
        weight.new*phi.param.vecs
      ave.param.list$phi.parent.param.vecs <- weight.current*ave.param.list$phi.parent.param.vecs +
        weight.new*phi.parent.param.vecs
      ave.param.list$phi.ave.param.vecs <- weight.current*ave.param.list$phi.ave.param.vecs +
        weight.new*phi.ave.param.vecs
    }}
    
            
  if(xi.update){
    if(i==1){
      ave.param.list$xi.param.vecs <- current.param.list$xi.param.vecs
      ave.param.list$theta.param.vecs <- current.param.list$theta.param.vecs
      if(hparam.update){
        ave.param.list$eta.vec <- current.param.list$eta.vec
        ave.param.list$lambda2 <- current.param.list$lambda2
      }
    } else {
      ave.param.list$xi.param.vecs <- weight.current*ave.param.list$xi.param.vecs +
        weight.new*current.param.list$xi.param.vecs
      ave.param.list$theta.param.vecs <- weight.current*ave.param.list$theta.param.vecs +
        weight.new*current.param.list$theta.param.vecs
      if(hparam.update){
        ave.param.list$lambda2 <- weight.current*ave.param.list$lambda2 +
          weight.new*current.param.list$lambda2
        ave.param.list$eta.vec <- weight.current*ave.param.list$eta.vec +
          weight.new*current.param.list$eta.vec
      }
    }}
    
  return(ave.param.list)
}


# Function to calculate quantities of interest for each draw of the Gibbs sampler
# Phi vectors
get.phi.vec <- function(mu.param.vecs,parent.child.list){
  # Set up phi matrix
  phi.param.vecs <- matrix(NA,ncol=ncol(mu.param.vecs),
                           nrow=nrow(mu.param.vecs),
                           dimnames=dimnames(mu.param.vecs))
  # Need rates
  beta.param.vecs <- exp(mu.param.vecs)
  # Get list of parents
  parents <- names(parent.child.list)
  # Get vector of phis and plug in phi.param.vecs
  for (parent in parents) {
    child.list <- parent.child.list[[parent]]
    beta.child <- beta.param.vecs[,child.list,drop=FALSE]
    beta.child.sum <- rowSums(beta.child)
    phi.param.vecs[,child.list] <- beta.child/beta.child.sum
  }

  return(phi.param.vecs)
}


get.phi.parent.vec <- function(mu.param.vecs,mu.corpus.vec,
                               parent.child.list){
  # Set up phi matrix
  phi.parent.param.vecs <- matrix(NA,ncol=ncol(mu.param.vecs),
                           nrow=nrow(mu.param.vecs),
                           dimnames=dimnames(mu.param.vecs))
  # Need rates
  beta.param.vecs <- exp(mu.param.vecs)
  # Get list of parents
  parents <- names(parent.child.list)
  # Get vector of phis and plug in phi.param.vecs
  for (parent in parents) {
    child.list <- parent.child.list[[parent]]
    beta.child <- beta.param.vecs[,child.list]
    if(parent=="CORPUS"){
      beta.parent <- exp(mu.corpus.vec)
    } else {beta.parent <- beta.param.vecs[,parent]}
    denom <- beta.parent + beta.child
    phi.parent.param.vecs[,child.list] <- beta.child/denom
  }

  return(phi.parent.param.vecs)
}


get.phi.ave.vec <- function(phi.param.vecs,phi.parent.param.vecs,
                            parent.child.list){
  
  # Set up phi matrix
  phi.ave.param.vecs <- matrix(NA,ncol=ncol(phi.param.vecs),
                               nrow=nrow(phi.param.vecs),
                               dimnames=dimnames(phi.param.vecs))

  # Get list of parents
  parents <- names(parent.child.list)
  # Get vector of phis and plug in phi.param.vecs
  for (parent in parents) {
    child.list <- parent.child.list[[parent]]
    nchild <- length(child.list)
    weight.parent <- 1/nchild
    weight.child <- 1 - weight.parent
    phi <- phi.param.vecs[,child.list]
    phi.parent <- phi.parent.param.vecs[,child.list]
    phi.ave.param.vecs[,child.list] <- weight.parent*phi.parent + weight.child*phi
  }

  return(phi.ave.param.vecs)
}
