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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
