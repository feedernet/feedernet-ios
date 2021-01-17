//
//  FeederTableViewCell.swift
//  FeederNet
//
//  Created by Marc Billow on 1/2/21.
//

import UIKit

class FeederTableViewCell: UITableViewCell {
    
    //MARK: Properties
    @IBOutlet weak var peripheralName: UILabel!
    @IBOutlet weak var peripheralIdentity: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusColor: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func prepareForReuse() {
        let wasAnimating = self.activityIndicator.isAnimating
        super.prepareForReuse()
        
        if wasAnimating {
            activityIndicator.startAnimating()
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
