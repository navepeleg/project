module "eks_blueprints" {
  source = "../modules"

  cluster_name    = local.eks_name
  cluster_version = "1.24"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/485
  # https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/494
  cluster_kms_key_additional_admin_arns = [data.aws_caller_identity.current.arn]

  fargate_profiles = {
    # Providing compute for default namespace
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [
        {
          namespace = "default"
      }]
      subnet_ids = module.vpc.private_subnets
    }
    # Providing compute for kube-system namespace where core addons reside
    kube_system = {
      fargate_profile_name = "kube-system"
      fargate_profile_namespaces = [
        {
          namespace = "kube-system"
      }]
      subnet_ids = module.vpc.private_subnets
    }
    # nginx application
    app = {
      fargate_profile_name = "app-nginx"
      fargate_profile_namespaces = [
        {
          namespace = "app-*"
      }]
      subnet_ids = module.vpc.private_subnets
    }
  }
  
  platform_teams = {
    admin = {
      users = [data.aws_caller_identity.current.arn]
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "../modules/modules/kubernetes-addons"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  # Wait on the `kube-system` profile before provisioning addons
  data_plane_wait_arn = module.eks_blueprints.fargate_profiles["kube_system"].eks_fargate_profile_arn

  enable_amazon_eks_vpc_cni = true
  amazon_eks_vpc_cni_config = {
    most_recent = true
  }

  enable_amazon_eks_kube_proxy = true
  amazon_eks_kube_proxy_config = {
    most_recent = true
  }

  enable_self_managed_coredns                    = true
  remove_default_coredns_deployment              = true
  enable_coredns_cluster_proportional_autoscaler = true
  self_managed_coredns_helm_config = {
    # Sets the correct annotations to ensure the Fargate provisioner is used and not the EC2 provisioner
    compute_type       = "fargate"
    kubernetes_version = module.eks_blueprints.eks_cluster_version
  }

  # Sample application
  enable_app_2048 = false

  # Enable Fargate logging
  enable_fargate_fluentbit = false
  fargate_fluentbit_addon_config = {
    flb_log_cw = false
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller_helm_config = {
    set_values = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "podDisruptionBudget.maxUnavailable"
        value = 1
      },
    ]
  }

  tags = local.tags
}

#test#